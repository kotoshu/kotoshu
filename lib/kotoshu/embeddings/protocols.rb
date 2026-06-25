# frozen_string_literal: true

# Protocols index - all protocol definitions
#
# This file provides access to all protocol modules.
# Protocols define contracts that implementations must follow.

require_relative 'protocols/embedding_model'
require_relative 'protocols/similarity_engine'
require_relative 'protocols/vocabulary'

# Namespace for protocol definitions (for backward compatibility)
module EmbeddingProtocols
  EmbeddingModel = ::EmbeddingModel
  SimilarityEngine = ::SimilarityEngine
  Vocabulary = ::Vocabulary
end
