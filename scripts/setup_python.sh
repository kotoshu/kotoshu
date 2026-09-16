#!/bin/bash
# Setup script for Kotoshu Python dependencies
#
# This script installs Python packages required for ONNX model conversion
# and validates the installation.

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Kotoshu Python Environment Setup                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 not found"
    echo ""
    echo "Please install Python 3.7 or later:"
    echo "  macOS: brew install python3"
    echo "  Ubuntu: sudo apt-get install python3"
    echo "  Windows: https://www.python.org/downloads/"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo "✓ Found Python $PYTHON_VERSION"
echo ""

# Check if pip is available
if ! python3 -m pip --version &> /dev/null; then
    echo "❌ Error: pip not found"
    echo ""
    echo "Please install pip:"
    echo "  macOS: python3 -m ensurepip --upgrade"
    echo "  Ubuntu: sudo apt-get install python3-pip"
    exit 1
fi

echo "✓ Found pip"
echo ""

# Install dependencies
echo "Installing Python dependencies from scripts/requirements.txt..."
echo ""

cd "$(dirname "$0")"

if [ ! -f "requirements.txt" ]; then
    echo "❌ Error: requirements.txt not found"
    echo "   Expected location: $(pwd)/requirements.txt"
    exit 1
fi

python3 -m pip install -r requirements.txt

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    ✓ Setup Complete!                            ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║                                                                ║"
echo "║  Installed packages:                                          ║"
echo "║  • onnx        - ONNX model creation and serialization        ║"
echo "║  • onnxruntime - Fast ONNX model inference                    ║"
echo "║  • numpy       - Vector operations                         ║"
echo "║                                                                ║"
echo "║  Next steps:                                                   ║"
echo "║  1. Convert FastText .vec to ONNX:                             ║"
echo "║     python3 scripts/convert_fasttext_to_onnx.py \\            ║"
echo "         --input cc.en.300.vec \\                               ║"
echo "         --output fasttext.en.onnx \\                             ║"
echo "         --language en                                         ║"
echo "║                                                                ║"
echo "║  2. Or download pre-converted models:                           ║"
echo "║     kotoshu model download en --type onnx                      ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
