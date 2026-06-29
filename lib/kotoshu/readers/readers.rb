# frozen_string_literal: true

# This file is intentionally a no-op stub.
#
# History: an earlier draft of the readers layer used `require_relative`
# here to eagerly load every reader file. The current design uses
# autoload declared in `lib/kotoshu/readers.rb` (the parent namespace
# file), so this nested file is redundant — and the `require_relative`
# calls violated the project rule against `require_relative` in lib/.
#
# Loading the original version of this file re-required already-loaded
# files (harmless but useless) and bypassed the autoload lazy-loading
# design. Rather than delete the file (project policy preserves files
# contributors may have local context for), it is reduced to this
# stub so any future `require` of it succeeds harmlessly.
#
# For the actual reader autoloads see: lib/kotoshu/readers.rb
