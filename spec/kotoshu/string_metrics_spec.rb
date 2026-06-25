# frozen_string_literal: true

require_relative "../../lib/kotoshu/string_metrics"

RSpec.describe Kotoshu::StringMetrics do
  describe ".commoncharacters" do
    it "counts matching characters at same positions" do
      expect(described_class.commoncharacters("hello", "hallo")).to eq(4)
      expect(described_class.commoncharacters("hello", "hello")).to eq(5)
      expect(described_class.commoncharacters("hello", "world")).to eq(1) # 'l' at position 3
    end

    it "handles empty strings" do
      expect(described_class.commoncharacters("", "hello")).to eq(0)
      expect(described_class.commoncharacters("hello", "")).to eq(0)
      expect(described_class.commoncharacters("", "")).to eq(0)
    end

    it "handles nil values" do
      expect(described_class.commoncharacters(nil, "hello")).to eq(0)
      expect(described_class.commoncharacters("hello", nil)).to eq(0)
    end

    it "handles strings of different lengths" do
      expect(described_class.commoncharacters("cat", "cats")).to eq(3)
      expect(described_class.commoncharacters("cats", "cat")).to eq(3)
    end
  end

  describe ".leftcommonsubstring" do
    it "calculates common prefix length" do
      expect(described_class.leftcommonsubstring("foo", "bar")).to eq(0)
      expect(described_class.leftcommonsubstring("built", "build")).to eq(4)
      expect(described_class.leftcommonsubstring("cat", "cats")).to eq(3)
    end

    it "returns 0 for completely different strings" do
      expect(described_class.leftcommonsubstring("hello", "world")).to eq(0)
    end

    it "returns full length when strings match" do
      expect(described_class.leftcommonsubstring("hello", "hello")).to eq(5)
    end

    it "returns shorter string length when one is prefix of other" do
      expect(described_class.leftcommonsubstring("cat", "category")).to eq(3)
    end

    it "handles empty strings" do
      expect(described_class.leftcommonsubstring("", "hello")).to eq(0)
      expect(described_class.leftcommonsubstring("hello", "")).to eq(0)
    end
  end

  describe ".ngram" do
    context "basic n-gram calculation" do
      it "calculates n-gram similarity" do
        # "hello" and "help" share: 'h', 'e', 'l', 'he', 'el'
        # 1-grams: h(✓), e(✓), l(✓), l(x), o(x) = 3
        # 2-grams: he(✓), el(✓), ll(x), lo(x) = 2
        # 3-grams: hel(✓), ell(x), llo(x) = 1
        # 4-grams: hell(x), ello(x) = 0
        result = described_class.ngram(4, "hello", "help")
        expect(result).to be >= 5 # At least some matches
      end

      it "handles completely different strings" do
        result = described_class.ngram(4, "abc", "xyz")
        expect(result).to eq(0)
      end

      it "handles identical strings" do
        result = described_class.ngram(3, "hello", "hello")
        expect(result).to be > 0
      end

      it "returns 0 for empty second string" do
        expect(described_class.ngram(3, "hello", "")).to eq(0)
      end
    end

    context "with weighted: true" do
      it "penalizes missing n-grams" do
        result_normal = described_class.ngram(3, "hello", "help")
        result_weighted = described_class.ngram(3, "hello", "help", weighted: true)

        # Weighted should be lower due to penalties
        expect(result_weighted).to be <= result_normal
      end

      it "penalizes missing prefix/suffix n-grams more" do
        # When prefix/suffix n-grams don't match, penalty is doubled
        result = described_class.ngram(3, "hello", "world", weighted: true)
        expect(result).to be < 0 # More penalties than matches
      end
    end

    context "with longer_worse: true" do
      it "penalizes when second string is significantly longer" do
        # "hello" vs "helloworld" - length difference of 5
        result_normal = described_class.ngram(3, "hello", "helloworld")
        result_penalty = described_class.ngram(3, "hello", "helloworld", longer_worse: true)

        # "helloworld" is much longer than "hello", so penalty applies
        expect(result_penalty).to be < result_normal
      end

      it "does not penalize small length differences" do
        # Length difference of 1-2 characters doesn't trigger penalty
        result = described_class.ngram(3, "cat", "cats", longer_worse: true)
        result_no_penalty = described_class.ngram(3, "cat", "cats")

        # Should be the same since penalty only applies for length diff > 2
        expect(result).to eq(result_no_penalty)
      end
    end

    context "with any_mismatch: true" do
      it "penalizes significant length differences" do
        # Length difference of more than 2 characters
        result1 = described_class.ngram(3, "hi", "helloworld", any_mismatch: true)
        result_normal = described_class.ngram(3, "hi", "helloworld")

        # Should have penalty due to large length difference
        expect(result1).to be < result_normal
      end

      it "does not penalize small length differences" do
        # Length difference of 1-2 characters doesn't trigger penalty
        result = described_class.ngram(3, "cat", "cats", any_mismatch: true)
        result_no_penalty = described_class.ngram(3, "cat", "cats")

        # Should be the same since penalty only applies for length diff > 2
        expect(result).to eq(result_no_penalty)
      end
    end

    context "real-world examples" do
      it "handles similar words with typos" do
        # "teachings" vs "teaching" - should have high similarity
        result = described_class.ngram(4, "teachings", "teaching")
        expect(result).to be > 5 # High similarity
      end

      it "handles transposition errors" do
        # "wrold" vs "world" - transposition of 'r' and 'o'
        result = described_class.ngram(4, "wrold", "world")
        expect(result).to be > 3 # Good similarity despite transposition
      end

      it "handles missing letter" do
        # "teh" vs "the" - missing 'h'
        result = described_class.ngram(3, "teh", "the")
        expect(result).to be > 0
      end

      it "handles extra letter" do
        # "teh" vs "thee" - extra 'e'
        result = described_class.ngram(3, "teh", "thee")
        expect(result).to be > 0
      end
    end
  end

  describe ".lcslen" do
    it "calculates longest common subsequence length" do
      # LCS of "AGGTAB" and "GXTXAYB" is "GTAB" of length 4
      expect(described_class.lcslen("AGGTAB", "GXTXAYB")).to eq(4)
    end

    it "handles empty strings" do
      expect(described_class.lcslen("", "hello")).to eq(0)
      expect(described_class.lcslen("hello", "")).to eq(0)
      expect(described_class.lcslen("", "")).to eq(0)
    end

    it "handles identical strings" do
      expect(described_class.lcslen("hello", "hello")).to eq(5)
    end

    it "handles completely different strings" do
      expect(described_class.lcslen("abc", "xyz")).to eq(0)
    end

    it "handles one string being subsequence of other" do
      expect(described_class.lcslen("abc", "aabbcc")).to eq(3)
      expect(described_class.lcslen("aabbcc", "abc")).to eq(3)
    end

    it "handles common subsequences at different positions" do
      # "ABCBDAB" and "BDCABA" have LCS "BCBA" or "BDAB" of length 4
      expect(described_class.lcslen("ABCBDAB", "BDCABA")).to eq(4)
    end

    context "real-world spelling correction examples" do
      it "finds common subsequence in similar words" do
        # "teachings" and "teaching" share "teaching" as common subsequence
        result = described_class.lcslen("teachings", "teaching")
        expect(result).to be >= 7 # Most characters match
      end

      it "handles transposition" do
        # "wrold" and "world"
        result = described_class.lcslen("wrold", "world")
        expect(result).to eq(4) # "wrld" is common
      end

      it "handles insertion/deletion" do
        # "beleived" vs "believed"
        result = described_class.lcslen("beleived", "believed")
        expect(result).to be >= 6 # Most characters match
      end
    end
  end

  describe "integration tests" do
    it "combines metrics for word similarity scoring" do
      word1 = "teachings"
      word2 = "teaching"

      # All metrics should show these words are similar
      cc = described_class.commoncharacters(word1, word2)
      lc = described_class.leftcommonsubstring(word1, word2)
      ng = described_class.ngram(4, word1, word2)
      lcs = described_class.lcslen(word1, word2)

      expect(cc).to be > 6  # Most characters match at same positions
      expect(lc).to be > 6  # Long common prefix
      expect(ng).to be > 10 # High n-gram similarity
      expect(lcs).to be > 6 # Long common subsequence
    end

    it "shows low similarity for dissimilar words" do
      word1 = "hello"
      word2 = "world"

      cc = described_class.commoncharacters(word1, word2)
      lc = described_class.leftcommonsubstring(word1, word2)
      ng = described_class.ngram(4, word1, word2)
      lcs = described_class.lcslen(word1, word2)

      expect(cc).to be < 3  # Few matching positions
      expect(lc).to be < 2  # Short common prefix
      expect(ng).to be < 5  # Low n-gram similarity
      expect(lcs).to be < 3 # Short common subsequence
    end
  end
end
