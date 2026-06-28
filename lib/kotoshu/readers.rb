# frozen_string_literal: true

module Kotoshu
  # Hunspell readers module for reading dictionary and affix files.
  module Readers
    autoload :FileReader, "kotoshu/readers/file_reader"
    autoload :StringReader, "kotoshu/readers/file_reader"
    autoload :ZipReader, "kotoshu/readers/file_reader"
    autoload :Affix, "kotoshu/readers/aff_data"
    autoload :BreakPattern, "kotoshu/readers/aff_data"
    autoload :Ignore, "kotoshu/readers/aff_data"
    autoload :RepPattern, "kotoshu/readers/aff_data"
    autoload :ConvTable, "kotoshu/readers/aff_data"
    autoload :CompoundRule, "kotoshu/readers/aff_data"
    autoload :CompoundPattern, "kotoshu/readers/aff_data"
    autoload :PhonetTable, "kotoshu/readers/aff_data"
    autoload :AffReader, "kotoshu/readers/aff_reader"
    autoload :DicReader, "kotoshu/readers/dic_reader"
    autoload :ConditionChecker, "kotoshu/readers/condition_checker"
    autoload :PassthroughConditionChecker, "kotoshu/readers/condition_checker"
    autoload :LatinScriptConditionChecker, "kotoshu/readers/condition_checker"
    autoload :LookupBuilder, "kotoshu/readers/lookup_builder"
    autoload :PhRepExtractor, "kotoshu/readers/lookup_builder"
  end
end
