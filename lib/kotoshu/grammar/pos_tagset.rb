# frozen_string_literal: true

module Kotoshu
  module Grammar
    # Namespace for POS tagset definitions (issue #277). The Urdu
    # tagset (CLE, LREC 2014 L14-1250) is the first member.
    module PosTagset
      autoload :Ur, "kotoshu/grammar/pos_tagset/ur"
    end
  end
end
