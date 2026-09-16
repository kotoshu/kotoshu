#!/bin/bash
# frozen_string_literal: true
#
# Download FastText models, convert to ONNX, and upload to kotoshu/dictionaries repository.
#
# Usage:
#   scripts/download_and_convert_models.sh [--languages de,en,es,fr,pt,ru] [--upload]
#
# This script:
# 1. Downloads FastText crawl vectors for specified languages
# 2. Converts each to ONNX format
# 3. Downloads language identification model
# 4. Optionally uploads to kotoshu/dictionaries repository
#
# Requirements:
#   - wget or curl
#   - Python 3 with numpy, onnx, onnxruntime
#   - GitHub CLI (gh) for upload

set -e

# Configuration
FASTTEXT_BASE_URL="https://dl.fbaipublicfiles.com/fasttext/vectors-crawl"
LID_MODEL_URL="https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.ftz"
REPO_NAME="kotoshu/dictionaries"
REPO_URL="https://github.com/${REPO_NAME}.git"
TEMP_DIR="/tmp/kotoshu-model-download"
WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Default: Full vocabulary for maximum coverage (2M words per language)
# WARNING: Large file sizes (~2.4GB per language)
# Set to lower value if bandwidth/storage is limited
DEFAULT_LANGUAGES="de,en,es,fr,pt,ru"
LANGUAGES="${LANGUAGES:-$DEFAULT_LANGUAGES}"

# Parse arguments
UPLOAD=false
CLEANUP=true
# FULL VOCABULARY by default (2M words per language)
MAX_VECTORS="${MAX_VECTORS:-2000000}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --languages)
      LANGUAGES="$2"
      shift 2
      ;;
    --upload)
      UPLOAD=true
      shift
      ;;
    --no-cleanup)
      CLEANUP=false
      shift
      ;;
    --max-vectors)
      MAX_VECTORS="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --languages LIST   Comma-separated language codes (default: $DEFAULT_LANGUAGES)"
      echo "  --upload           Upload to kotoshu/dictionaries repository"
      echo "  --no-cleanup       Keep temporary files"
      echo "  --max-vectors N    Maximum vectors (default: 2000000 = FULL vocabulary)"
      echo "  --help             Show this help"
      echo ""
      echo "WARNING: Full vocabulary downloads ~2.4GB per language!"
      echo ""
      echo "Example: Download and upload for English and German"
      echo "  $0 --languages en,de --upload"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     FastText Model Download, Convert, and Upload Script      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Languages: $LANGUAGES"
echo "Max vectors: $MAX_VECTORS"
echo "Upload: $UPLOAD"
echo ""

# Create temporary directory
echo "Creating temporary directory: $TEMP_DIR"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Convert comma-separated languages to array
IFS=',' read -ra LANG_ARRAY <<< "$LANGUAGES"

# Download and convert each language
for lang in "${LANG_ARRAY[@]}"; do
  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "Processing language: $lang"
  echo "══════════════════════════════════════════════════════════════════"

  # Download crawl vectors
  vec_file="cc.$lang.300.vec"
  vec_url="$FASTTEXT_BASE_URL/$vec_file"

  echo "Downloading $vec_url..."
  wget -c -O "$TEMP_DIR/$vec_file" "$vec_url" || {
    echo "Failed to download $vec_file"
    continue
  }

  # Also download the bin version for reference
  bin_file="cc.$lang.300.bin"
  bin_url="$FASTTEXT_BASE_URL/$bin_file"

  echo "Downloading $bin_url..."
  wget -c -O "$TEMP_DIR/$bin_file" "$bin_url" || {
    echo "Failed to download $bin_file (continuing anyway)"
  }

  # Convert to ONNX
  onnx_file="fasttext.$lang.onnx"

  echo "Converting to ONNX..."
  python3 "$WORK_DIR/scripts/convert_fasttext_to_onnx.py" \
    --input "$TEMP_DIR/$vec_file" \
    --output "$TEMP_DIR/$onnx_file" \
    --language "$lang" \
    --max-vectors "$MAX_VECTORS" \
    --validate || {
    echo "Failed to convert $lang to ONNX"
    continue
  }

  echo "✓ Converted $lang to ONNX"
done

# Download language identification model
echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "Downloading language identification model"
echo "══════════════════════════════════════════════════════════════════"

echo "Downloading $LID_MODEL_URL..."
wget -c -O "$TEMP_DIR/lid.176.ftz" "$LID_MODEL_URL"

echo "✓ Downloaded language identification model"

# Upload to repository if requested
if [ "$UPLOAD" = true ]; then
  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "Uploading to $REPO_NAME"
  echo "══════════════════════════════════════════════════════════════════"

  # Clone repository
  REPO_DIR="$TEMP_DIR/dictionaries"
  echo "Cloning $REPO_URL..."
  git clone "$REPO_URL" "$REPO_DIR"

  # Copy files for each language
  for lang in "${LANG_ARRAY[@]}"; do
    echo ""
    echo "Uploading files for $lang..."

    # Create directories
    mkdir -p "$REPO_DIR/$lang/models/fasttext"
    mkdir -p "$REPO_DIR/$lang/models/onnx"

    # Copy files
    vec_file="cc.$lang.300.vec"
    bin_file="cc.$lang.300.bin"
    onnx_file="fasttext.$lang.onnx"

    if [ -f "$TEMP_DIR/$vec_file" ]; then
      cp "$TEMP_DIR/$vec_file" "$REPO_DIR/$lang/models/fasttext/"
      echo "  ✓ Copied $vec_file"
    fi

    if [ -f "$TEMP_DIR/$bin_file" ]; then
      cp "$TEMP_DIR/$bin_file" "$REPO_DIR/$lang/models/fasttext/"
      echo "  ✓ Copied $bin_file"
    fi

    if [ -f "$TEMP_DIR/$onnx_file" ]; then
      cp "$TEMP_DIR/$onnx_file" "$REPO_DIR/$lang/models/onnx/"
      echo "  ✓ Copied $onnx_file"
    fi

    # Copy vocab and metadata files
    for ext in .vocab.json .metadata.json .ort.onnx; do
      base_file="$TEMP_DIR/fasttext.$lang.onnx"
      if [ -f "${base_file}${ext}" ]; then
        cp "${base_file}${ext}" "$REPO_DIR/$lang/models/onnx/"
        echo "  ✓ Copied fasttext.$lang.onnx${ext}"
      fi
    done
  done

  # Copy language identification model
  echo ""
  echo "Uploading language identification model..."
  mkdir -p "$REPO_DIR/models"
  cp "$TEMP_DIR/lid.176.ftz" "$REPO_DIR/models/"
  echo "  ✓ Copied lid.176.ftz"

  # Commit and push
  cd "$REPO_DIR"
  git add .

  # Check if there are changes to commit
  if git diff --staged --quiet; then
    echo "No changes to commit"
  else
    git commit -m "Add FastText models and ONNX conversions

Languages: $LANGUAGES
- FastText crawl vectors (.vec, .bin)
- ONNX converted models (.onnx)
- Optimized ORT models (.ort.onnx)
- Vocabulary and metadata files
- Language identification model (lid.176.ftz)

Generated by: kotoshu download_and_convert_models.sh
Max vectors: $MAX_VECTORS
"

    # Check if gh is available and authenticated
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
      echo "Pushing to remote..."
      git push
      echo "✓ Pushed to $REPO_NAME"
    else
      echo "⚠ GitHub CLI not available or not authenticated"
      echo "  Please push manually:"
      echo "  cd $REPO_DIR && git push"
    fi
  fi

  cd "$WORK_DIR"
fi

# Cleanup
if [ "$CLEANUP" = true ]; then
  echo ""
  echo "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
  echo "✓ Cleaned up"
else
  echo ""
  echo "Temporary files kept at: $TEMP_DIR"
fi

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "✓ Script completed successfully!"
echo "══════════════════════════════════════════════════════════════════"
