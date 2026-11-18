# frozen_string_literal: true

module Kotoshu
  module Cache
    # Vendored staged-language list (plan 107). This file is GENERATED:
    # refreshed by rake kotoshu:staged_languages:sync from the
    # dictionaries manifest at the SourceRegistry pin. Edit the
    # dictionaries repo, not this file.
    #
    # Two tiers of support (plan 107 vocabulary):
    # - full feature: a language module under Kotoshu::Languages
    #   (keyboard layout + verified specimens + tokenizer care) —
    #   see LanguageCache.full_feature_languages;
    # - basic: manifest-present but module-less — the script fallback
    #   tokenizer and generic keyboard still serve check/suggest.
    module StagedLanguages
      # Language codes carried by the dictionaries manifest at its
      # SourceRegistry pin; refreshed by the sync rake task above.
      CODES = %w[
                 ar bg br ca ca-valencia cs cy da de de-AT de-CH el el-polyton
                 en en-AU en-CA en-GB en-ZA eo es es-AR es-BO es-CL es-CO es-CR es-CU
                 es-DO es-EC es-GT es-HN es-MX es-NI es-PA es-PE es-PH es-PR es-PY es-SV es-US
                 es-UY es-VE et eu fa fo fr fur fy ga gd gl he
                 hr hu hy hyw ia id ie is it ka ko la lb
                 lt ltg lv mk mn nb nds ne nl nn oc pl pt
                 pt-BR pt-PT ro ru rw sk sl sr sr-Latn sv sv-FI tk tlh
                 tlh-Latn tr uk ur vi].freeze
    end
  end
end
