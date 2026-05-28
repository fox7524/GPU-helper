#!/usr/bin/env python3
"""
MLX LLM decode benchmark (prefill + decode) with minimal sync overhead.

Usage examples:
  python3 mlx_decode_bench.py --model /path/to/mlx_model --prompt-len 8192 --gen-len 256
  python3 mlx_decode_bench.py --model /path/to/mlx_model --prompt "Hello" --gen-len 256

Notes:
  - This script targets Apple Silicon + MLX. Run it on your Mac (not inside this VM).
  - It tries to use mlx-lm if installed. Install:
      pip install mlx mlx-lm --break-system-packages
"""

from __future__ import annotations

import argparse
import os
import time
from dataclasses import dataclass
from typing import Any, Optional, Tuple


def now_s() -> float:
    return time.perf_counter()


@dataclass
class BenchResult:
    prefill_s: float
    decode_s: float
    gen_len: int

    @property
    def decode_s_per_tok(self) -> float:
        return self.decode_s / max(self.gen_len, 1)

    @property
    def decode_tok_per_s(self) -> float:
        return self.gen_len / max(self.decode_s, 1e-12)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="MLX LLM prefill+decode benchmark.")
    p.add_argument("--model", required=True, help="Path to an MLX model folder.")

    # Prompt options: either actual text (tokenized) or synthetic token length.
    p.add_argument("--prompt", default=None, help="Prompt text (if provided, overrides --prompt-len).")
    p.add_argument("--prompt-len", type=int, default=2048, help="Synthetic prompt length in tokens.")

    p.add_argument("--gen-len", type=int, default=256, help="Number of tokens to generate.")
    p.add_argument("--batch", type=int, default=1, help="Batch size (start with 1 for interactive).")

    # Measurement.
    p.add_argument("--warmup", type=int, default=1, help="Warmup runs (not reported).")
    p.add_argument("--runs", type=int, default=3, help="Measured runs (best-of reported).")
    p.add_argument("--eval-every", type=int, default=1, help="Call mx.eval every N decode steps (>=1).")

    # Sampling (keep simple; greedy is fastest/most stable for benchmarking).
    p.add_argument("--temperature", type=float, default=0.0, help="0.0 = greedy decoding.")

    return p.parse_args()


def _require_dir(path: str) -> None:
    if not os.path.isdir(path):
        raise SystemExit(f"--model must be a directory. Got: {path}")


def _load_with_mlx_lm(model_path: str) -> Tuple[Any, Any]:
    """
    Returns: (model, tokenizer)
    """
    try:
        from mlx_lm import load  # type: ignore
    except Exception as e:  # pragma: no cover
        raise SystemExit(
            "Could not import mlx_lm. Install with:\n"
            "  pip install mlx mlx-lm --break-system-packages\n"
            f"Import error: {e}"
        )

    model, tokenizer = load(model_path)
    return model, tokenizer


def _tokenize(tokenizer: Any, text: str) -> list[int]:
    # Tokenizers differ a bit; try common patterns.
    if hasattr(tokenizer, "encode"):
        return tokenizer.encode(text)
    if callable(tokenizer):
        out = tokenizer(text)
        # Some tokenizers return dict with input_ids.
        if isinstance(out, dict) and "input_ids" in out:
            return list(out["input_ids"])
        if isinstance(out, (list, tuple)):
            return list(out)
    raise SystemExit("Tokenizer does not support encode(). Please share your tokenizer type.")


def _make_synth_tokens(vocab_size: int, prompt_len: int, batch: int) -> "mx.array":
    import mlx.core as mx

    # Deterministic synthetic prompt: [1,2,3,...] mod vocab_size (avoid CPU RNG overhead).
    base = mx.arange(prompt_len, dtype=mx.int32) % max(vocab_size, 1)
    if batch == 1:
        return base[None, :]
    return mx.repeat(base[None, :], repeats=batch, axis=0)


def _prefill_and_make_cache(model: Any, tokens: "mx.array") -> Tuple["mx.array", Any]:
    """
    Run prefill on the full prompt to populate KV cache.
    Returns: (logits, cache)
    """
    # mlx-lm models typically accept (tokens, cache=...) and return (logits, cache)
    out = model(tokens)
    if isinstance(out, tuple) and len(out) == 2:
        logits, cache = out
        return logits, cache
    # Some variants return logits only and store cache inside; handle minimally.
    return out, getattr(model, "cache", None)


def _decode_step(model: Any, token_1: "mx.array", cache: Any) -> Tuple["mx.array", Any]:
    out = model(token_1, cache=cache)
    if isinstance(out, tuple) and len(out) == 2:
        logits, cache = out
        return logits, cache
    return out, getattr(model, "cache", cache)


def _select_next_token(logits: "mx.array", temperature: float) -> "mx.array":
    import mlx.core as mx

    # logits: [B, 1, V] or [B, V]
    if logits.ndim == 3:
        logits = logits[:, -1, :]
    if temperature and temperature > 0.0:
        # Sampling adds overhead; keep it optional.
        probs = mx.softmax(logits / temperature, axis=-1)
        return mx.random.categorical(probs, axis=-1).astype(mx.int32)
    # Greedy
    return mx.argmax(logits, axis=-1).astype(mx.int32)


def run_one(model: Any, tokenizer: Any, args: argparse.Namespace) -> BenchResult:
    import mlx.core as mx

    # Build tokens (avoid Python work inside the timed section).
    if args.prompt is not None:
        ids = _tokenize(tokenizer, args.prompt)
        if len(ids) == 0:
            raise SystemExit("Prompt tokenized to empty.")
        # Shape [B, T]
        tokens = mx.array([ids] * args.batch, dtype=mx.int32)
    else:
        vocab_size = getattr(tokenizer, "vocab_size", None)
        if vocab_size is None:
            # Fallback if tokenizer doesn't expose vocab_size.
            vocab_size = 32000
        tokens = _make_synth_tokens(int(vocab_size), args.prompt_len, args.batch)

    # -------------------------
    # Prefill: one big eval.
    # -------------------------
    t0 = now_s()
    logits, cache = _prefill_and_make_cache(model, tokens)
    mx.eval(logits)  # force completion (one sync point)
    prefill_s = now_s() - t0

    # Initialize next token from last logits.
    next_tok = _select_next_token(logits, args.temperature)
    next_tok = next_tok[:, None]  # [B, 1]

    # -------------------------
    # Decode: 1 token per step.
    # Keep exactly ONE mx.eval per step group (eval-every).
    # -------------------------
    eval_every = max(int(args.eval_every), 1)

    t1 = now_s()
    pending = []
    for i in range(args.gen_len):
        logits, cache = _decode_step(model, next_tok, cache)
        next_tok = _select_next_token(logits, args.temperature)[:, None]

        # Accumulate a small number of steps before syncing.
        pending.append(next_tok)
        if (i + 1) % eval_every == 0:
            mx.eval(logits, next_tok)
            pending.clear()

    if pending:
        mx.eval(logits, next_tok)
    decode_s = now_s() - t1

    return BenchResult(prefill_s=prefill_s, decode_s=decode_s, gen_len=args.gen_len)


def main() -> None:
    args = parse_args()
    _require_dir(args.model)

    # Load model/tokenizer.
    model, tokenizer = _load_with_mlx_lm(args.model)

    # Warmups.
    for _ in range(max(args.warmup, 0)):
        _ = run_one(model, tokenizer, args)

    # Measured runs: report best (least) decode time to reduce noise.
    best: Optional[BenchResult] = None
    for _ in range(max(args.runs, 1)):
        r = run_one(model, tokenizer, args)
        if best is None or r.decode_s < best.decode_s:
            best = r

    assert best is not None
    total = best.prefill_s + best.decode_s
    prompt_len = len(_tokenize(tokenizer, args.prompt)) if args.prompt is not None else args.prompt_len

    print("=== MLX Decode Benchmark (best-of) ===")
    print(f"model:        {args.model}")
    print(f"batch:        {args.batch}")
    print(f"prompt_len:   {prompt_len}")
    print(f"gen_len:      {args.gen_len}")
    print(f"eval_every:   {max(int(args.eval_every), 1)}")
    print("")
    print(f"prefill:      {best.prefill_s*1000:.2f} ms  ({prompt_len/best.prefill_s:.1f} tok/s equivalent)")
    print(f"decode:       {best.decode_s*1000:.2f} ms  ({best.decode_tok_per_s:.1f} tok/s, {best.decode_s_per_tok*1000:.3f} ms/tok)")
    print(f"end-to-end:   {total*1000:.2f} ms")


if __name__ == "__main__":
    main()

