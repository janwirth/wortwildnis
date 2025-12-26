defmodule WortwildnisWeb.DescriptionSegmenterTest do
  use ExUnit.Case, async: true

  alias WortwildnisWeb.DescriptionSegmenter

  describe "build_description_segments/2" do
    test "returns text segment for empty term list" do
      result = DescriptionSegmenter.build_description_segments("Hello world", [])
      assert result == [{:text, "Hello world"}]
    end

    test "returns text segment when no terms match" do
      term = %{name: "foo", id: 1}
      result = DescriptionSegmenter.build_description_segments("Hello world", [term])
      assert result == [{:text, "Hello world"}]
    end

    test "links a single term at the end" do
      term = %{name: "world", id: 1}
      result = DescriptionSegmenter.build_description_segments("Hello world", [term])
      assert result == [{:text, "Hello "}, {:link, term, "world"}]
    end

    test "links a single term at the beginning" do
      term = %{name: "Hello", id: 1}
      result = DescriptionSegmenter.build_description_segments("Hello world", [term])
      assert result == [{:link, term, "Hello"}, {:text, " world"}]
    end

    test "links a single term in the middle" do
      term = %{name: "beautiful", id: 1}
      result = DescriptionSegmenter.build_description_segments("Hello beautiful world", [term])
      assert result == [{:text, "Hello "}, {:link, term, "beautiful"}, {:text, " world"}]
    end

    test "links multiple different terms" do
      term1 = %{name: "Hello", id: 1}
      term2 = %{name: "world", id: 2}
      result = DescriptionSegmenter.build_description_segments("Hello world", [term1, term2])
      assert result == [{:link, term1, "Hello"}, {:text, " "}, {:link, term2, "world"}]
    end

    test "links only first occurrence of a term" do
      term = %{name: "foo", id: 1}
      result = DescriptionSegmenter.build_description_segments("foo bar foo", [term])
      assert result == [{:link, term, "foo"}, {:text, " bar foo"}]
    end

    test "preserves original case in matched text" do
      term = %{name: "world", id: 1}
      result = DescriptionSegmenter.build_description_segments("Hello WORLD", [term])
      assert result == [{:text, "Hello "}, {:link, term, "WORLD"}]
    end

    test "case-insensitive matching" do
      term = %{name: "WoRlD", id: 1}
      result = DescriptionSegmenter.build_description_segments("Hello world", [term])
      assert result == [{:text, "Hello "}, {:link, term, "world"}]
    end

    test "respects word boundaries for terms shorter than 4 characters - does not match partial words" do
      term = %{name: "tes", id: 1}
      result = DescriptionSegmenter.build_description_segments("This is testing", [term])
      assert result == [{:text, "This is testing"}]
    end

    test "ignores word boundaries for terms longer than 3 characters - matches partial words" do
      term = %{name: "test", id: 1}
      result = DescriptionSegmenter.build_description_segments("This is testing", [term])
      assert result == [{:text, "This is "}, {:link, term, "test"}, {:text, "ing"}]
    end

    test "matches whole words with punctuation boundaries" do
      term = %{name: "word", id: 1}
      result = DescriptionSegmenter.build_description_segments("Hello, word!", [term])
      assert result == [{:text, "Hello, "}, {:link, term, "word"}, {:text, "!"}]
    end

    test "matches term when it is part of a compound word with hyphen" do
      term = %{name: "test", id: 1}
      result = DescriptionSegmenter.build_description_segments("pre-test-post", [term])
      # Hyphens are word boundaries, so "test" should be matched
      assert result == [{:text, "pre-"}, {:link, term, "test"}, {:text, "-post"}]
    end

    test "matches longer terms first to avoid partial matches" do
      term1 = %{name: "New York", id: 1}
      term2 = %{name: "York", id: 2}

      result =
        DescriptionSegmenter.build_description_segments("I live in New York", [term1, term2])

      # Should match "New York" as a whole (longer term processed first)
      # "York" is not matched because "New York" already consumed it
      assert result == [{:text, "I live in "}, {:link, term1, "New York"}]
    end

    test "matches shorter term when longer term doesn't match" do
      term1 = %{name: "New York", id: 1}
      term2 = %{name: "York", id: 2}
      result = DescriptionSegmenter.build_description_segments("I visited York", [term1, term2])
      # Should only match "York" since "New York" is not present
      assert result == [{:text, "I visited "}, {:link, term2, "York"}]
    end

    test "handles multiple terms with overlapping names - longer term matched first" do
      term1 = %{name: "bar", id: 1}
      term2 = %{name: "foo bar", id: 2}
      result = DescriptionSegmenter.build_description_segments("foo bar test", [term1, term2])
      # Longer term "foo bar" is processed first and matches
      # Shorter term "bar" does not match because it was consumed by "foo bar"
      assert result == [{:link, term2, "foo bar"}, {:text, " test"}]
    end

    test "handles multiple terms with overlapping names - longer term matched first, then shorter term" do
      term1 = %{name: "bar", id: 1}
      term2 = %{name: "foo bar", id: 2}

      result =
        DescriptionSegmenter.build_description_segments("foo bar test foo bar", [term1, term2])

      # Longer term "foo bar" is processed first and matches
      # Shorter term "bar" does not match because it was consumed by "foo bar"
      assert result == [{:link, term2, "foo bar"}, {:text, " test foo "}, {:link, term1, "bar"}]
    end

    test "handles text with only a term and no surrounding text" do
      term = %{name: "hello", id: 1}
      result = DescriptionSegmenter.build_description_segments("hello", [term])
      assert result == [{:link, term, "hello"}]
    end

    test "handles empty description" do
      term = %{name: "hello", id: 1}
      result = DescriptionSegmenter.build_description_segments("", [term])
      # Empty string returns a single text segment with empty string
      assert result == [{:text, ""}]
    end

    test "handles term with special regex characters" do
      term = %{name: "C++", id: 1}
      result = DescriptionSegmenter.build_description_segments("I love C++", [term])
      assert result == [{:text, "I love "}, {:link, term, "C++"}]
    end

    test "handles terms with parentheses" do
      term = %{name: "(test)", id: 1}
      result = DescriptionSegmenter.build_description_segments("This is (test) case", [term])
      assert result == [{:text, "This is "}, {:link, term, "(test)"}, {:text, " case"}]
    end

    test "handles consecutive terms without spaces" do
      term1 = %{name: "foo", id: 1}
      term2 = %{name: "bar", id: 2}
      # With punctuation between them
      result = DescriptionSegmenter.build_description_segments("foo,bar", [term1, term2])
      assert result == [{:link, term1, "foo"}, {:text, ","}, {:link, term2, "bar"}]
    end

    test "handles terms in a complex sentence" do
      term1 = %{name: "Elixir", id: 1}
      term2 = %{name: "Phoenix", id: 2}
      term3 = %{name: "web framework", id: 3}
      text = "Elixir is great! Phoenix is a powerful web framework built with Elixir."
      result = DescriptionSegmenter.build_description_segments(text, [term1, term2, term3])

      # Only first occurrence of each term is linked
      assert result == [
               {:link, term1, "Elixir"},
               {:text, " is great! "},
               {:link, term2, "Phoenix"},
               {:text, " is a powerful "},
               {:link, term3, "web framework"},
               {:text, " built with Elixir."}
             ]
    end

    test "handles repeated terms - only links first occurrence" do
      term = %{name: "test", id: 1}
      result = DescriptionSegmenter.build_description_segments("test test test", [term])

      assert result == [
               {:link, term, "test"},
               {:text, " test test"}
             ]
    end

    test "does not create empty text segments" do
      term1 = %{name: "Hello", id: 1}
      term2 = %{name: "world", id: 2}
      result = DescriptionSegmenter.build_description_segments("Hello world", [term1, term2])

      # Should not have any empty text segments
      Enum.each(result, fn
        {:text, text} -> assert String.length(text) > 0
        {:link, _, _} -> :ok
      end)
    end

    test "handles numbers in term names" do
      term = %{name: "Web 3.0", id: 1}
      result = DescriptionSegmenter.build_description_segments("Web 3.0 is here", [term])
      assert result == [{:link, term, "Web 3.0"}, {:text, " is here"}]
    end

    test "handles underscores in term names" do
      term = %{name: "snake_case", id: 1}
      result = DescriptionSegmenter.build_description_segments("I use snake_case", [term])
      assert result == [{:text, "I use "}, {:link, term, "snake_case"}]
    end

    test "matches terms with mixed case and special characters" do
      term = %{name: "React.js", id: 1}
      result = DescriptionSegmenter.build_description_segments("I love React.js!", [term])
      assert result == [{:text, "I love "}, {:link, term, "React.js"}, {:text, "!"}]
    end

    test "handles German umlauts" do
      term = %{name: "Über", id: 1}
      result = DescriptionSegmenter.build_description_segments("Das ist über gut", [term])
      # Should match case-insensitively
      assert result == [{:text, "Das ist "}, {:link, term, "über"}, {:text, " gut"}]
    end

    test "handles terms at various positions with different punctuation" do
      term = %{name: "test", id: 1}

      # Parentheses
      result1 = DescriptionSegmenter.build_description_segments("(test)", [term])
      assert result1 == [{:text, "("}, {:link, term, "test"}, {:text, ")"}]

      # Square brackets
      result2 = DescriptionSegmenter.build_description_segments("[test]", [term])
      assert result2 == [{:text, "["}, {:link, term, "test"}, {:text, "]"}]

      # Quotes
      result3 = DescriptionSegmenter.build_description_segments("\"test\"", [term])
      assert result3 == [{:text, "\""}, {:link, term, "test"}, {:text, "\""}]
    end

    test "complex example" do
      sentence =
        "Abwertende Bemerkung über die Qualität eines Essens.\n" <>
          "Das Gericht erfüllt gerade so seinen Zweck, den Magen zu füllen, schmeckt aber meist schlecht."

      result =
        DescriptionSegmenter.build_description_segments(
          sentence,
          [
            %{id: "1", name: "Ende"},
            %{id: "2", name: "über"},
            %{id: "3", name: "Quali"},
            %{id: "4", name: "Essen"},
            %{id: "5", name: "Weck"},
            %{id: "6", name: "Magen"},
            %{id: "7", name: "schmeckt"},
            %{id: "8", name: "schlecht"}
          ]
        )

      assert result == [
               {:text, "Abwert"},
               {:link, %{id: "1", name: "Ende"}, "ende"},
               {:text, " Bemerkung "},
               {:link, %{id: "2", name: "über"}, "über"},
               {:text, " die "},
               {:link, %{id: "3", name: "Quali"}, "Quali"},
               {:text, "tät eines "},
               {:link, %{id: "4", name: "Essen"}, "Essen"},
               {:text, "s.\nDas Gericht erfüllt gerade so seinen Z"},
               {:link, %{id: "5", name: "Weck"}, "weck"},
               {:text, ", den "},
               {:link, %{id: "6", name: "Magen"}, "Magen"},
               {:text, " zu füllen, "},
               {:link, %{id: "7", name: "schmeckt"}, "schmeckt"},
               {:text, " aber meist "},
               {:link, %{id: "8", name: "schlecht"}, "schlecht"},
               {:text, "."}
             ]
    end
  end
end
