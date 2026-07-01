#!/usr/bin/env python3
"""
Local LLM summarization via MLX + mlx-lm.
Takes a transcript JSON file and outputs structured summary as JSON.

Usage:
  python3 summarize.py <transcript.json> [--model MODEL_NAME]

Input transcript JSON format:
  [{"speaker": "SPEAKER_00", "text": "...", "start": 0.0, "end": 2.5}, ...]

Output JSON:
  {"summary": "...", "decisions": [...], "team_todos": [...], "per_person_todos": {...}}
"""

import sys
import json
import argparse
import os


PROMPT_TEMPLATE = """<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are a meeting assistant. Given a transcript with speaker labels, produce:
1. A concise summary (3-5 sentences).
2. Key decisions made.
3. A list of action items with owners if clear, otherwise mark as "Team".
4. A separate per-person to-do list for each speaker.

Output ONLY valid JSON. No markdown, no explanation.

{
  "summary": "...",
  "decisions": ["...", "..."],
  "team_todos": ["...", "..."],
  "per_person_todos": {
    "SPEAKER_00": ["..."],
    "SPEAKER_01": ["..."]
  }
}<|eot_id|><|start_header_id|>user<|end_header_id|>

Transcript:
{transcript}<|eot_id|><|start_header_id|>assistant<|end_header_id|>"""


def build_transcript_text(segments):
    lines = []
    for seg in segments:
        start = seg.get("start", 0)
        end = seg.get("end", 0)
        speaker = seg.get("speaker", "SPEAKER_00")
        text = seg.get("text", "")
        lines.append(f"[{start:.1f}-{end:.1f}] {speaker}: {text}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("transcript_path", help="Path to transcript JSON file")
    parser.add_argument("--model", default="mlx-community/Llama-3.1-8B-Instruct-4bit",
                        help="MLX model name (default: Llama-3.1-8B-Instruct-4bit)")
    args = parser.parse_args()

    if not os.path.isfile(args.transcript_path):
        print(json.dumps({"error": f"File not found: {args.transcript_path}"}))
        sys.exit(1)

    try:
        import mlx.core as mx
        from mlx_lm import load, generate
    except ImportError:
        print(json.dumps({"error": "MLX not installed. Run: pip install mlx mlx-lm"}))
        sys.exit(1)

    try:
        with open(args.transcript_path) as f:
            segments = json.load(f)
    except Exception as e:
        print(json.dumps({"error": f"Cannot read transcript: {e}"}))
        sys.exit(1)

    if not segments:
        print(json.dumps({"error": "Empty transcript"}))
        sys.exit(1)

    transcript_text = build_transcript_text(segments)
    prompt = PROMPT_TEMPLATE.format(transcript=transcript_text)

    try:
        mx.metal.set_default_memory_limit(8 * 1024 * 1024 * 1024)  # 8 GB

        model, tokenizer = load(args.model)
        response = generate(model, tokenizer, prompt, max_tokens=1024, verbose=False)

        response = response.strip()
        if response.startswith("```json"):
            response = response[7:]
        if response.startswith("```"):
            response = response[3:]
        if response.endswith("```"):
            response = response[:-3]
        response = response.strip()

        result = json.loads(response)

        required = ["summary", "decisions", "team_todos", "per_person_todos"]
        for key in required:
            if key not in result:
                result[key] = [] if key != "summary" else ""

        print(json.dumps(result, ensure_ascii=False))

    except Exception as e:
        print(json.dumps({"error": f"Generation failed: {e}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
