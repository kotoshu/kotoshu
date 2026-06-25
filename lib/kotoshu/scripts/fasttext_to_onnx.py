#!/usr/bin/env python3
"""
FastText to ONNX Converter

Converts FastText .vec files to ONNX format for efficient deployment.
The ONNX model contains an embedding lookup layer with the word vectors.

Usage:
    python fasttext_to_onnx.py <vec_file> <output_onnx> [--vocab_size N]

Example:
    python fasttext_to_onnx.py cc.en.300.vec fasttext.en.onnx --vocab_size 50000
"""

import sys
import argparse
import json
from pathlib import Path

import numpy as np
import onnx
from onnx import helper, numpy_helper
from onnx import TensorProto


def parse_fasttext_vec(vec_file_path, vocab_size=None):
    """
    Parse FastText .vec file and extract vocabulary and embeddings.

    Args:
        vec_file_path: Path to FastText .vec file
        vocab_size: Maximum vocabulary size (None for all words)

    Returns:
        tuple: (vocab_dict, embeddings_array, metadata)
            - vocab_dict: Dictionary mapping word to index
            - embeddings_array: NumPy array of shape [vocab_size, embedding_dim]
            - metadata: Dictionary with file metadata
    """
    print(f"Parsing FastText file: {vec_file_path}")

    word_to_idx = {}
    embeddings = []
    metadata = {
        "source_format": "fasttext_vec",
        "embedding_dim": None,
        "vocab_size": 0,
        "total_words_in_file": 0
    }

    with open(vec_file_path, 'r', encoding='utf-8') as f:
        # First line: vocab_size and dimension
        first_line = f.readline().strip()
        parts = first_line.split()
        total_vocab = int(parts[0])
        embedding_dim = int(parts[1])

        metadata["embedding_dim"] = embedding_dim
        metadata["total_words_in_file"] = total_vocab

        print(f"  Total words in file: {total_vocab}")
        print(f"  Embedding dimension: {embedding_dim}")

        # Limit vocab size if specified
        if vocab_size is None or vocab_size > total_vocab:
            vocab_size = total_vocab

        metadata["vocab_size"] = vocab_size

        print(f"  Loading {vocab_size} words...")

        # Read embeddings
        for idx in range(vocab_size):
            line = f.readline()
            if not line:
                break

            parts = line.strip().split()
            word = parts[0]
            vector = np.array([float(x) for x in parts[1:]], dtype=np.float32)

            word_to_idx[word] = idx
            embeddings.append(vector)

            if (idx + 1) % 10000 == 0:
                print(f"    Loaded {idx + 1} words...")

    # Stack embeddings into a matrix
    embeddings_matrix = np.vstack(embeddings).astype(np.float32)

    print(f"  Embeddings matrix shape: {embeddings_matrix.shape}")
    print(f"  Matrix size in MB: {embeddings_matrix.nbytes / (1024 * 1024):.2f}")

    return word_to_idx, embeddings_matrix, metadata


def create_onnx_model(embeddings_matrix, word_to_idx, model_name="fasttext"):
    """
    Create ONNX model with embedding lookup layer.

    Args:
        embeddings_matrix: NumPy array of word embeddings [vocab_size, embedding_dim]
        word_to_idx: Dictionary mapping words to indices
        model_name: Name for the ONNX model

    Returns:
        onnx.ModelProto: ONNX model
    """
    vocab_size, embedding_dim = embeddings_matrix.shape

    print(f"Creating ONNX model...")
    print(f"  Input: word_index (int64)")
    print(f"  Output: embedding (float32, shape=[{embedding_dim}])")

    # Create input (word index)
    input_tensor = helper.make_tensor_value_info(
        'word_index',
        TensorProto.INT64,
        [1]  # Scalar input (single word index)
    )

    # Create output (embedding vector)
    output_tensor = helper.make_tensor_value_info(
        'embedding',
        TensorProto.FLOAT,
        [embedding_dim]
    )

    # Create initializers for the embedding matrix
    embedding_initializer = numpy_helper.from_array(embeddings_matrix, name='word_embeddings')

    # Create Constant node for the embedding matrix
    embedding_constant = helper.make_node(
        'Constant',
        inputs=[],
        outputs=['embeddings_matrix'],
        value=embedding_initializer
    )

    # Create Gather node to lookup embedding by index
    gather_node = helper.make_node(
        'Gather',
        inputs=['embeddings_matrix', 'word_index'],
        outputs=['embedding_flat'],
        axis=0
    )

    # Create Squeeze node to remove the batch dimension
    squeeze_node = helper.make_node(
        'Squeeze',
        inputs=['embedding_flat'],
        outputs=['embedding'],
        axes=[0]  # Remove first dimension
    )

    # Create graph
    graph = helper.make_graph(
        [embedding_constant, gather_node, squeeze_node],
        f'{model_name}_embedding',
        [input_tensor],
        [output_tensor]
    )

    # Create model
    model = helper.make_model(
        graph,
        producer_name='kotoshu-fasttext-converter',
        producer_version='1.0.0',
        opset_imports=[helper.make_operatorsetid('', 11)],  # ONNX opset 11 for compatibility
        ir_version=11  # Set IR version to match opset
    )

    # Add metadata
    from onnx import StringStringEntryProto
    model.metadata_props.append(StringStringEntryProto(key='vocabulary_size', value=str(vocab_size)))
    model.metadata_props.append(StringStringEntryProto(key='embedding_dimension', value=str(embedding_dim)))
    model.metadata_props.append(StringStringEntryProto(key='model_type', value='fasttext_embedding'))

    print(f"  ONNX model created successfully")

    return model


def save_vocabulary(word_to_idx, vocab_file_path):
    """
    Save vocabulary dictionary to JSON file.

    Args:
        word_to_idx: Dictionary mapping words to indices
        vocab_file_path: Path to save vocabulary file
    """
    print(f"Saving vocabulary to: {vocab_file_path}")

    vocab_data = {
        "vocab_size": len(word_to_idx),
        "word_to_idx": word_to_idx
    }

    with open(vocab_file_path, 'w', encoding='utf-8') as f:
        json.dump(vocab_data, f, ensure_ascii=False, indent=2)

    print(f"  Vocabulary saved: {len(word_to_idx)} words")


def main():
    parser = argparse.ArgumentParser(
        description='Convert FastText .vec file to ONNX format'
    )
    parser.add_argument(
        'vec_file',
        type=str,
        help='Path to FastText .vec file'
    )
    parser.add_argument(
        'output_onnx',
        type=str,
        help='Path to output ONNX file'
    )
    parser.add_argument(
        '--vocab-size',
        type=int,
        default=None,
        help='Maximum vocabulary size (default: all words)'
    )
    parser.add_argument(
        '--save-vocab',
        type=str,
        default=None,
        help='Path to save vocabulary JSON file (optional)'
    )

    args = parser.parse_args()

    # Validate input file
    vec_file = Path(args.vec_file)
    if not vec_file.exists():
        print(f"Error: Input file not found: {vec_file}")
        sys.exit(1)

    # Parse FastText file
    word_to_idx, embeddings_matrix, metadata = parse_fasttext_vec(
        vec_file,
        vocab_size=args.vocab_size
    )

    # Create ONNX model
    model = create_onnx_model(embeddings_matrix, word_to_idx)

    # Save ONNX model
    output_path = Path(args.output_onnx)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"Saving ONNX model to: {output_path}")
    onnx.save(model, str(output_path))
    print(f"  Model saved successfully")

    # Calculate file sizes
    vec_size_mb = vec_file.stat().st_size / (1024 * 1024)
    onnx_size_mb = output_path.stat().st_size / (1024 * 1024)

    print(f"\nFile size comparison:")
    print(f"  Input .vec file:  {vec_size_mb:.2f} MB")
    print(f"  Output .onnx file: {onnx_size_mb:.2f} MB")
    print(f"  Compression ratio: {(vec_size_mb / onnx_size_mb):.2f}x")

    # Save vocabulary if requested
    if args.save_vocab:
        save_vocabulary(word_to_idx, args.save_vocab)

    print(f"\nConversion complete!")
    print(f"  Model metadata: {metadata}")


if __name__ == '__main__':
    main()
