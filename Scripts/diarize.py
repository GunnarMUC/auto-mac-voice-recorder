#!/usr/bin/env python3
"""
Speaker diarization using Pyannote.audio 3.1.

Usage:
  python3 diarize.py <audio.wav>
  python3 diarize.py <audio.wav> --device cpu|cuda|mps

Output: JSON with segments array or error.
"""

import sys
import json
import argparse
import os


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("audio_path", help="Path to WAV file")
    parser.add_argument("--device", default=None, help="Torch device (cpu, cuda, mps)")
    args = parser.parse_args()

    if not os.path.isfile(args.audio_path):
        print(json.dumps({"error": f"File not found: {args.audio_path}"}))
        sys.exit(1)

    try:
        import torch
        from pyannote.audio import Pipeline

        pipeline = Pipeline.from_pretrained(
            "pyannote/speaker-diarization-3.1",
            use_auth_token=None,
        )

        if args.device:
            pipeline.to(torch.device(args.device))

        diarization = pipeline(args.audio_path)

        segments = []
        for turn, _, speaker in diarization.itertracks(yield_label=True):
            segments.append({
                "speaker": speaker,
                "start": round(turn.start, 2),
                "end": round(turn.end, 2),
            })

        print(json.dumps({"segments": segments}))

    except ImportError as e:
        print(json.dumps({"error": f"Missing dependency: {e}"}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
