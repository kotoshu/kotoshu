# frozen_string_literal: true

module Kotoshu
  # Embedding models for semantic spell checking (FastText via ONNX),
  # and core domain value objects (Word, AffixRule, Result types).
  #
  # Note: Word, AffixRule, and Result types live under Kotoshu::Models
  # for historical reasons even though their files are in core/models/.
  module Models
    autoload :Word, "kotoshu/core/models/word"
    autoload :AffixRule, "kotoshu/core/models/affix_rule"
    autoload :Context, "kotoshu/models/context"
    autoload :EmbeddingModel, "kotoshu/models/embedding_model"
    autoload :FastTextModel, "kotoshu/models/fasttext_model"
    autoload :NearestNeighbor, "kotoshu/models/nearest_neighbor"
    autoload :OnnxModel, "kotoshu/models/onnx_model"
    autoload :SemanticError, "kotoshu/models/semantic_error"
    autoload :Suggestion, "kotoshu/models/suggestion"
    autoload :WordEmbedding, "kotoshu/models/word_embedding"

    # Result sub-namespace (word/document check results).
    module Result
      autoload :WordResult, "kotoshu/core/models/result/word_result"
      autoload :DocumentResult, "kotoshu/core/models/result/document_result"
    end
  end
end
