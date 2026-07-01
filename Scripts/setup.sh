#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "=== CallRecorder — Speaker Diarization Setup ==="
echo ""

# Create virtual environment
if [ ! -d ".venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv .venv
fi

source .venv/bin/activate

echo "Installing PyTorch (CPU + MPS for Apple Silicon)..."
pip install --upgrade pip
pip install torch torchaudio

echo ""
echo "Installing Pyannote.audio..."
pip install "pyannote.audio>=3.1"

echo ""
echo "=== Setup complete ==="
echo ""
echo "To use diarization, you need to accept the user conditions for the model:"
echo "  1. Create an account at https://huggingface.co"
echo "  2. Accept conditions at https://huggingface.co/pyannote/speaker-diarization-3.1"
echo "  3. Generate a token at https://huggingface.co/settings/tokens"
echo "  4. Run: huggingface-cli login --token YOUR_TOKEN"
echo ""
echo "Then run the app as usual."
