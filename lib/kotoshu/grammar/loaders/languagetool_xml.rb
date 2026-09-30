# frozen_string_literal: true

require "moxml"

module Kotoshu
  module Grammar
    module Loaders
      # Converts LanguageTool rule XML into Kotoshu pattern rules
      # (TODO.grammar/7).
      #
      # LanguageTool is LGPL-2.1+; this loader reads their XML format
      # and emits rule hashes carrying `source: languagetool` and
      # `license: LGPL-2.1+`. Converted rules keep LT's license.
      #
      # XML processing goes through Moxml with the leptris adapter.
      #
      # Design: everything expressible in the Kotoshu pattern DSL is
      # converted; anything else (and/or groups, unify, unmappable
      # postags, match postag_transforms, inflected tokens) causes the
      # rule to be skipped and counted in the stats, so coverage is
      # always explicit.
      #
      # @example
      #   loader = LanguageToolXml.new(File.read("grammar.xml"))
      #   loader.rules     # => [{ "id" => ..., "pattern" => [...] }, ...]
      #   loader.stats     # => { converted: 1234, skipped: 540, ... }
      class LanguageToolXml
        class Unsupported < StandardError
        end

        attr_reader :rules, :stats

        def initialize(xml, language: "en")
          @language = language
          @rules = []
          @stats = { converted: 0, skipped: 0, skip_reasons: Hash.new(0) }
          @doc = Moxml.parse(xml)
          convert
        end

        private

        def convert
          @doc.xpath("/rules//rulegroup").each do |group|
            group_id = group["id"]
            group.xpath("rule").each_with_index do |rule, i|
              convert_rule(rule, group_id, rule["id"] ? nil : i)
            end
          end
          @doc.xpath("/rules//rule").each do |rule|
            next if rule.parent.name == "rulegroup"

            convert_rule(rule, nil)
          end
        end

        def convert_rule(node, group_id, unnamed_index = nil)
          id = unnamed_index ? unnamed_index.to_s : node["id"]
          full_id = group_id ? "#{group_id}_#{id}" : id
          pattern_node = node.at_xpath("pattern")
          raise Unsupported, "no_pattern" if pattern_node.nil? || pattern_node.xpath("token").empty?

          rule_hash = build_rule_hash(node, full_id, pattern_node)
          @rules << rule_hash
          @stats[:converted] += 1
        rescue Unsupported => e
          @stats[:skipped] += 1
          @stats[:skip_reasons][e.message.to_sym] += 1
        end

        def build_rule_hash(node, full_id, pattern_node)
          pattern = pattern_node.xpath("token").map { |t| convert_token(t) }
          raise Unsupported, "empty_pattern" if pattern.empty?

          if pattern_node["case_sensitive"] == "yes"
            pattern.each { |tok| tok["case_sensitive"] = true }
          end

          message, suggestions = convert_message(node.at_xpath("message"))
          raise Unsupported, "no_message" if message.nil? || message.empty?

          hash = {
            "id" => full_id,
            "name" => node["name"],
            "category" => category_of(node),
            "language" => @language,
            "matcher" => "pos_sequence",
            "pattern" => pattern,
            "message" => message,
            "suggestions" => suggestions,
            "source" => "languagetool",
            "license" => "LGPL-2.1+"
          }
          antipatterns = convert_antipatterns(node)
          hash["unless_pattern"] = antipatterns unless antipatterns.empty?
          hash["default"] = node["default"] if node["default"]
          examples = convert_examples(node)
          hash["examples"] = examples unless examples.empty?
          hash
        end

        def convert_token(token)
          raise Unsupported, "and_or" if token.xpath("and").any? || token.xpath("or").any?
          raise Unsupported, "inflected" if token["inflected"] == "yes"
          raise Unsupported, "chunk_phrasename" if token["chunk"] || token["phrasename"]

          word = direct_text(token)
          raise Unsupported, "empty_token" if word.empty? && token["postag"].nil?

          constraint = {}

          if token["postag"]
            pos = PosMapper.map(token["postag"], regexp: token["postag_regexp"] == "yes")
            raise Unsupported, "unmappable_postag" if pos.nil?

            constraint["pos"] = pos
          end

          unless word.empty?
            if token["regexp"] == "yes"
              constraint["regex"] = word
              begin
                Regexp.new("\\A(?:#{word})\\z")
              rescue RegexpError
                raise Unsupported, "invalid_regex"
              end
            elsif word.include?("|")
              constraint["word"] = word.split("|")
            else
              constraint["word"] = word
            end
          end

          constraint["negated"] = true if token["negated"] == "yes"
          constraint["case_sensitive"] = true if token["case_sensitive"] == "yes"

          min = token["min"]&.to_i
          max = token["max"]&.to_i
          if min
            raise Unsupported, "repeat_range" unless (min == 1 && (max.nil? || max == 1)) || (min.zero? && max.to_i <= 1)

            constraint["optional"] = true if min.zero?
          end

          constraint["skip"] = token["skip"].to_i if token["skip"]

          convert_exceptions(token, constraint)
          constraint
        end

        # LT tokens carry their word as DIRECT text children; inline
        # <exception> children must not leak into it (Moxml Element#text
        # concatenates all descendants, which is wrong here).
        def direct_text(element)
          element.children.grep(Moxml::Text).map(&:text).join.strip
        end

        def convert_exceptions(token, constraint)
          exceptions = token.xpath("exception")
          return if exceptions.empty?

          raise Unsupported, "and_or" if exceptions.any? { |e| e.xpath("and").any? || e.xpath("or").any? }

          words = []
          pos_tags = []
          exceptions.each do |exc|
            scope = exc["scope"]
            exc_word = direct_text(exc)
            if exc["regexp"] == "yes"
              begin
                Regexp.new("\\A(?:#{exc_word})\\z")
              rescue RegexpError
                raise Unsupported, "invalid_exception_regex"
              end
              key = scope == "previous" ? "previous_exception_regex" : "exception_regex"
              (constraint[key] ||= []) << exc_word
            elsif exc_word != ""
              if scope == "previous"
                (constraint["previous_exception"] ||= []) << exc_word
              else
                words << exc_word
              end
            end
            next unless exc["postag"]

            mapped = PosMapper.map(exc["postag"], regexp: exc["postag_regexp"] == "yes")
            raise Unsupported, "unmappable_exception_postag" if mapped.nil?

            pos_tags.concat(Array(mapped))
          end
          constraint["exception"] = words unless words.empty?
          constraint["exception_pos"] = pos_tags.uniq unless pos_tags.empty?
        end

        def convert_message(message_node)
          return [nil, []] if message_node.nil?

          suggestions = []
          parts = []
          message_node.children.each do |child|
            if child.is_a?(Moxml::Element) && child.name == "suggestion"
              text = suggestion_text(child)
              suggestions << text
              parts << "\"#{text}\""
            else
              parts << child.text.to_s
            end
          end
          message = parts.join.strip
          [message, suggestions]
        end

        def suggestion_text(suggestion_node)
          out = +""
          suggestion_node.children.each do |child|
            if child.is_a?(Moxml::Element) && child.name == "match"
              raise Unsupported, "match_postag_transform" if child.attributes.any? { |a| a.name.start_with?("postag") }

              # LT match numbers are 1-based; the DSL is 0-based
              out << "{{#{child['no'].to_i - 1}}}"
            else
              out << child.text.to_s
            end
          end
          out.strip
        end

        def convert_antipatterns(node)
          sources = [node] + [node.parent].select { |p| p.is_a?(Moxml::Element) && p.name == "rulegroup" }
          sources.flat_map { |src| src.xpath("antipattern").to_a }.map do |ap|
            tokens = ap.xpath("token").map { |t| convert_token(t) }
            raise Unsupported, "empty_antipattern" if tokens.empty?

            if ap["case_sensitive"] == "yes"
              tokens.each { |tok| tok["case_sensitive"] = true }
            end
            tokens
          rescue Unsupported => e
            raise Unsupported, "antipattern_#{e.message}"
          end
        end

        def convert_examples(node)
          node.xpath("example").map do |ex|
            # Element#text concatenates all descendant text, exactly
            # what the sentence needs (marker contents included).
            text = ex.text.to_s
            entry = {}
            if ex["correction"]
              entry["bad"] = text
              entry["correction"] = ex["correction"]
            elsif ex["type"] == "triggers_error"
              entry["bad"] = text
            else
              entry["good"] = text
            end
            entry
          end.reject(&:empty?)
        end

        def category_of(node)
          parent = node.parent
          while parent.is_a?(Moxml::Element) && parent.name != "category"
            parent = parent.parent
          end
          return "grammar" unless parent.is_a?(Moxml::Element)

          parent["type"] || parent["name"] || "grammar"
        end
      end
    end
  end
end
