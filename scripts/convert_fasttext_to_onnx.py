#!/usr/bin/env python3
"""
Convert FastText .vec files to ONNX format for faster inference.

This script reads FastText pre-trained word vectors (.vec format) and
converts them to ONNX format that can be loaded by ONNX Runtime.

Usage:
    python scripts/convert_fasttext_to_onnx.py --input cc.en.300.vec --output fasttext.en.onnx

Requirements:
    pip install numpy onnx onnxruntime

The ONNX model will have:
- Input: word indices (int64 tensor)
- Output: word embeddings (float32 tensor)
- Optimized graph with ORT format
"""

import argparse
import json
import os
import struct
from typing import Dict, List, Tuple

import numpy as np
import onnx
from onnx import helper, numpy_helper
import onnxruntime as ort


def read_fasttext_vec_file(filepath: str, max_vectors: int = 1000000) -> Tuple[Dict[str, int], np.ndarray]:
    """
    Read FastText .vec file.

    Args:
        filepath: Path to .vec file
        max_vectors: Maximum number of vectors to load

    Returns:
        Tuple of (vocabulary dict, embeddings matrix)
        vocabulary: {word: index} mapping
        embeddings: numpy array of shape (vocab_size, dimension)
    """
    print(f"Reading FastText file: {filepath}")

    vocab = {}
    embeddings_list = []

    with open(filepath, 'r', encoding='utf-8') as f:
        # First line: vocab_size dimension
        first_line = f.readline()
        parts = first_line.split()
        vocab_size = int(parts[0])
        dimension = int(parts[1])

        print(f"  Vocab size: {vocab_size}")
        print(f"  Dimension: {dimension}")
        print(f"  Loading max {max_vectors} vectors...")

        # Read vectors
        for idx, line in enumerate(f):
            if idx >= max_vectors:
                break

            if (idx + 1) % 100000 == 0:
                print(f"  Loaded {idx + 1} vectors...")

            parts = line.strip().split()
            if len(parts) < dimension + 1:
                continue

            word = parts[0]
            vector = np.array([float(x) for x in parts[1:dimension + 1]], dtype=np.float32)

            vocab[word] = idx
            embeddings_list.append(vector)

    embeddings = np.array(embeddings_list, dtype=np.float32)
    print(f"  Loaded {len(vocab)} vectors of shape {embeddings.shape}")

    return vocab, embeddings


def create_onnx_model(
    embeddings: np.ndarray,
    vocab: Dict[str, int],
    model_name: str = "fasttext_embeddings"
) -> onnx.ModelProto:
    """
    Create ONNX model with embedding lookup.

    Args:
        embeddings: Embeddings matrix (vocab_size x dimension)
        vocab: Vocabulary dict {word: index}
        model_name: Name for the ONNX model

    Returns:
        ONNX ModelProto
    """
    vocab_size, dimension = embeddings.shape

    print(f"Creating ONNX model...")

    # Create input (word index or batch of word indices)
    input_tensor = helper.make_tensor_value_info(
        'word_indices',
        onnx.TensorProto.INT64,
        ['batch_size']  # Can be 1 for single word lookup
    )

    # Create output (embeddings)
    output_tensor = helper.make_tensor_value_info(
        'embeddings',
        onnx.TensorProto.FLOAT,
        ['batch_size', dimension]
    )

    # Create initializer for embedding matrix
    embedding_initializer = numpy_helper.from_array(embeddings, name='embedding_matrix')

    # Create constant node for the embedding matrix
    embedding_constant = helper.make_node(
        'Constant',
        inputs=[],
        outputs=['embedding_matrix_constant'],
        value=embedding_initializer
    )

    # Create Gather node to lookup embeddings by index
    gather_node = helper.make_node(
        'Gather',
        inputs=['embedding_matrix_constant', 'word_indices'],
        outputs=['embeddings'],
        axis=0
    )

    # Create graph
    graph = helper.make_graph(
        [embedding_constant, gather_node],
        model_name,
        [input_tensor],
        [output_tensor]
    )

    # Create model
    model = helper.make_model(
        graph,
        producer_name='kotoshu-fasttext-converter',
        producer_version='1.0.0'
    )

    # Add metadata
    # Skip metadata for compatibility with different ONNX versions

    print(f"  Model created: {vocab_size} words x {dimension} dimensions")

    return model


def save_model_with_metadata(
    model: onnx.ModelProto,
    output_path: str,
    vocab: Dict[str, int],
    language_code: str,
    dimension: int = 300
):
    """
    Save ONNX model with metadata.

    Args:
        model: ONNX model
        output_path: Output file path
        vocab: Vocabulary dict
        language_code: ISO 639-1 language code
        dimension: Embedding dimension
    """
    # Save ONNX model
    print(f"Saving ONNX model to: {output_path}")
    onnx.save(model, output_path)

    # Save vocabulary as JSON (for word-to-index mapping)
    vocab_path = output_path.replace('.onnx', '.vocab.json')
    print(f"Saving vocabulary to: {vocab_path}")

    with open(vocab_path, 'w', encoding='utf-8') as f:
        json.dump(vocab, f, ensure_ascii=False, indent=2)

    # Save metadata
    metadata_path = output_path.replace('.onnx', '.metadata.json')
    print(f"Saving metadata to: {metadata_path}")

    # Get dimension from embeddings shape since we skipped metadata
    import numpy as np
    actual_dimension = dimension

    metadata = {
        'model_type': 'fasttext',
        'format': 'onnx',
        'language': language_code,
        'vocabulary_size': len(vocab),
        'dimension': int(actual_dimension),
        'input': 'word_indices (int64)',
        'output': 'embeddings (float32)',
        'created_by': 'kotoshu-fasttext-converter'
    }

    with open(metadata_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2)

    # Optimize to ORT format
    print("Optimizing model...")
    session_options = ort.SessionOptions()
    session_options.optimized_model_filepath = output_path.replace('.onnx', '.ort.onnx')
    session = ort.InferenceSession(output_path, sess_options=session_options)

    print(f"Optimized model saved to: {session_options.optimized_model_filepath}")


def validate_model(model_path: str):
    """
    Validate the ONNX model by loading and running inference.

    Args:
        model_path: Path to ONNX model
    """
    print(f"Validating model: {model_path}")

    try:
        # Load vocabulary
        vocab_path = model_path.replace('.onnx', '.vocab.json')
        with open(vocab_path, 'r', encoding='utf-8') as f:
            vocab = json.load(f)

        # Load model
        session = ort.InferenceSession(model_path)

        # Test lookup for first word
        test_word = list(vocab.keys())[0]
        test_index = vocab[test_word]

        result = session.run(
            None,
            {'word_indices': np.array([test_index], dtype=np.int64)}
        )

        embedding = result[0][0]

        print(f"  ✓ Model loaded successfully")
        print(f"  ✓ Test word '{test_word}' (index {test_index})")
        print(f"  ✓ Embedding shape: {embedding.shape}")
        print(f"  ✓ Embedding sample: {embedding[:3]}")

        return True

    except Exception as e:
        print(f"  ✗ Validation failed: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Convert FastText .vec files to ONNX format'
    )
    parser.add_argument(
        '--input', '-i',
        required=True,
        help='Input FastText .vec file'
    )
    parser.add_argument(
        '--output', '-o',
        required=True,
        help='Output ONNX file'
    )
    parser.add_argument(
        '--language', '-l',
        required=True,
        help='Language code (e.g., en, de, fr)'
    )
    parser.add_argument(
        '--max-vectors', '-m',
        type=int,
        default=500000,
        help='Maximum vectors to load (default: 500000)'
    )
    parser.add_argument(
        '--validate',
        action='store_true',
        help='Validate model after creation'
    )

    args = parser.parse_args()

    # Read FastText file
    vocab, embeddings = read_fasttext_vec_file(args.input, args.max_vectors)

    # Create ONNX model
    model = create_onnx_model(embeddings, vocab)

    # Save model
    save_model_with_metadata(
        model,
        args.output,
        vocab,
        args.language,
        dimension=embeddings.shape[1]
    )

    # Validate if requested
    if args.validate:
        validate_model(args.output)

    print("\n✓ Conversion complete!")


if __name__ == '__main__':
    main()
