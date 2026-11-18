"""Rebuild a sentencepiece .model proto from the extracted pieces table
(de-v1/pieces.json.bak-79649) so the Python SentencePieceProcessor can
serve as the conformance oracle for the Ruby unigram encoder (TODO 152).

Scores: sentencepiece exports log-probs in the proto — pieces.json
stores them verbatim (verified: '▁' = -2.32, '.' = -3.754 — log scale).
Types: 1 normal, 2 unknown, 3 control, 6 byte.
"""
import json
import sys

try:
    from sentencepiece import sentencepiece_model_pb2 as sp_pb2
except ImportError:
    sys.exit("sentencepiece package required (pip install sentencepiece)")

pieces = json.load(open(sys.argv[1], encoding="utf-8"))
out_path = sys.argv[2]

proto = sp_pb2.ModelProto()
proto.trainer_spec.model_type = sp_pb2.TrainerSpec.UNIGRAM
proto.trainer_spec.vocab_size = len(pieces)
proto.normalizer_spec.name = "nmt_nfkc"
proto.normalizer_spec.add_dummy_prefix = True
proto.trainer_spec.byte_fallback = True

TYPE_MAP = {1: sp_pb2.ModelProto.SentencePiece.NORMAL,
            2: sp_pb2.ModelProto.SentencePiece.UNKNOWN,
            3: sp_pb2.ModelProto.SentencePiece.CONTROL,
            4: sp_pb2.ModelProto.SentencePiece.USER_DEFINED,
            6: sp_pb2.ModelProto.SentencePiece.BYTE}

for p in pieces:
    piece = proto.pieces.add()
    piece.piece = p["piece"]
    piece.score = p.get("score", 0.0)
    piece.type = TYPE_MAP.get(p.get("type", 1), sp_pb2.ModelProto.SentencePiece.NORMAL)

with open(out_path, "wb") as f:
    f.write(proto.SerializeToString())
print(f"proto rebuilt: {len(pieces)} pieces -> {out_path}")

# smoke: the rebuilt proto must load and encode
import sentencepiece as spm
sp = spm.SentencePieceProcessor(model_proto=proto.SerializeToString())
sample = "La tecnologia moderna cambia rapidamente"
print("smoke encode:", sp.encode(sample, out_type=str)[:8])
