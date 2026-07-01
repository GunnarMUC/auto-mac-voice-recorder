#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "=== CallRecorder — AI Setup ==="
echo ""

if [ ! -d ".venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv .venv
fi

source .venv/bin/activate

echo "Installing/upgrading pip..."
pip install --upgrade pip

echo ""
echo "=== Installing PyTorch (Apple Silicon MPS) ==="
pip install torch torchaudio

echo ""
echo "=== Installing Pyannote.audio (Speaker Diarization) ==="
pip install "pyannote.audio>=3.1"

echo ""
echo "=== Installing MLX + mlx-lm (Local LLM for Summarization) ==="
pip install mlx mlx-lm

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo ""
echo "1. HuggingFace Login (for diarization model):"
echo "   huggingface-cli login --token YOUR_TOKEN"
echo ""
echo "2. Download LLM model (will happen automatically on first use):"
echo "   python3 -c \"from mlx_lm import load; load('mlx-community/Llama-3.1-8B-Instruct-4bit')\""
echo ""
echo "3. Run the app:"
echo "   swift run CallRecorder"
