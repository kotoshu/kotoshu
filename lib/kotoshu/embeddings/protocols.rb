# frozen_string_literal: true

# This file is intentionally a no-op stub.
#
# History: an earlier draft of the embeddings layer planned to split
# protocol definitions across `protocols/embedding_model.rb`,
# `protocols/similarity_engine.rb`, and `protocols/vocabulary.rb`.
# Those subfiles were never created; the protocols were inlined into
# `protocol.rb` (singular) instead, which is what the autoload table
# in `lib/kotoshu/embeddings.rb` points at.
#
# Loading the original version of this file raised LoadError because
# `require_relative 'protocols/embedding_model'` referenced a path
# that did not exist. Rather than delete the file (project policy
# preserves files contributors may have local context for), it is
# reduced to this stub so any future `require` of it succeeds
# harmlessly.
#
# For the actual protocol definitions see:
#   Kotoshu::Embeddings::EmbeddingModelProtocol
#   Kotoshu::Embeddings::SimilarityEngineProtocol
#   Kotoshu::Embeddings::VocabularyProtocol
# all in lib/kotoshu/embeddings/protocol.rb.
