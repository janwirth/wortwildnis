defmodule WortwildnisWeb.DescriptionSegmenter do
  @moduledoc """
  Processes description text to identify and link contained terms.

  This module takes a description string and a list of terms that are contained
  within that description, and returns a list of segments that can be rendered
  as a mix of plain text and links.

  ## Segments

  The module returns segments in the following formats:
  - `{:text, text}` - plain text that should be rendered as-is
  - `{:link, term_slug, original_text}` - a term reference that should be rendered as a link,
    where `term_slug` is the slugified term name and `original_text` is the matched text from the
    description (preserving original case)

  ## Matching Rules

  - Case-insensitive matching
  - Word boundary matching:
    - Terms shorter than 4 characters must match whole words only (respect both boundaries)
    - Terms 4+ characters can match anywhere (substring matching - no boundary requirements)
  - Longer terms are matched first to avoid partial matches
  - Each term is matched only once (first occurrence only)
  - Already linked segments are not processed again
  """

  @doc """
  Builds a list of text and link segments from a description and its contained terms.

  ## Examples

      iex> build_description_segments("Hello world", [])
      [{:text, "Hello world"}]

      iex> term = %{name: "world", id: 1}
      iex> build_description_segments("Hello world", [term])
      [{:text, "Hello "}, {:link, "world", "world"}]

      iex> term1 = %{name: "foo", id: 1}
      iex> term2 = %{name: "bar", id: 2}
      iex> build_description_segments("foo and bar", [term1, term2])
      [{:text, "Hello "}, {:link, "foo", "foo"}, {:text, " and "}, {:link, "bar", "bar"}]
  """
  def build_description_segments(description, []) when is_binary(description),
    do: [{:text, description}]

  def build_description_segments(description, contained_terms) when is_binary(description) do
    # Sort terms by length descending to match longer terms first (avoid partial matches)
    sorted_terms = Enum.sort_by(contained_terms, &String.length(&1.name), :desc)

    # Start with the full description as a single text segment
    # Then process each term to find and replace matches
    initial_segments = [{:text, description}]

    Enum.reduce(sorted_terms, initial_segments, fn term, segments ->
      replace_term_in_segments(segments, term)
    end)
  end

  defp replace_term_in_segments(segments, term) do
    term_name_lower = String.downcase(term.name)

    {result, _found} =
      Enum.flat_map_reduce(segments, false, fn
        {:text, text}, false ->
          # Only process text segments if we haven't found a match yet for this term
          case replace_term_in_text(text, term_name_lower, term) do
            [{:text, ^text}] ->
              # No match found in this segment, continue searching
              {[{:text, text}], false}

            segments_with_link ->
              # Match found for this term, mark as found
              {segments_with_link, true}
          end

        {:text, text}, true ->
          # Already found a match for this term, keep remaining text segments as-is
          {[{:text, text}], true}

        {:link, _, _} = link_segment, found ->
          # Skip link segments (already processed)
          {[link_segment], found}
      end)

    result
  end

  defp replace_term_in_text(text, term_name_lower, term) do
    text_lower = String.downcase(text)

    # Find all occurrences of the term (case-insensitive)
    case find_all_occurrences(text_lower, term_name_lower, text) do
      [] ->
        # No matches found
        [{:text, text}]

      positions ->
        # Build segments from matches
        build_segments_from_positions(text, positions, term)
    end
  end

  defp find_all_occurrences(text_lower, pattern, original_text) do
    find_all_occurrences(text_lower, pattern, original_text, 0, [])
  end

  defp find_all_occurrences(text_lower, pattern, original_text, start_pos, acc) do
    case :binary.match(text_lower, pattern, [
           {:scope, {start_pos, byte_size(text_lower) - start_pos}}
         ]) do
      {pos, len} ->
        pattern_length = byte_size(pattern)

        # Terms shorter than 4 characters must respect word boundaries (whole words)
        # Terms 4+ characters can match anywhere (substring matching - no boundary checks)

        if pattern_length < 4 do
          # Check if this is a whole word match (both boundaries)
          if is_whole_word_match(text_lower, pos, len) do
            # Only match the first occurrence, return immediately
            [{pos, len}]
          else
            # Not a whole word, continue searching from after this position
            find_all_occurrences(text_lower, pattern, original_text, pos + 1, acc)
          end
        else
          # For longer terms (4+ characters), match anywhere without boundary checks
          [{pos, len}]
        end

      :nomatch ->
        []
    end
  end

  defp is_whole_word_match(text, byte_pos, byte_len) do
    # Check character before match (if exists)
    # byte_pos and byte_len are byte positions from :binary.match
    char_before_ok =
      if byte_pos > 0 do
        <<_::binary-size(byte_pos - 1), char_byte::8, _::binary>> = text
        char_before = <<char_byte>>
        is_word_boundary?(char_before)
      else
        # Start of string is a word boundary
        true
      end

    # Check character after match (if exists)
    char_after_ok =
      if byte_pos + byte_len < byte_size(text) do
        <<_::binary-size(byte_pos + byte_len), char_byte::8, _::binary>> = text
        char_after = <<char_byte>>
        is_word_boundary?(char_after)
      else
        # End of string is a word boundary
        true
      end

    char_before_ok && char_after_ok
  end

  defp is_word_boundary?(char) when is_binary(char) do
    # Word boundary: not a letter, digit, or underscore
    case char do
      <<c::utf8>> ->
        not (char?(c, ?a, ?z) or char?(c, ?A, ?Z) or char?(c, ?0, ?9) or c == ?_)

      _ ->
        # Non-printable or multi-byte, treat as boundary
        true
    end
  end

  defp char?(c, min, max), do: c >= min and c <= max

  defp build_segments_from_positions(text, positions, term) do
    # Sort positions to process from left to right
    sorted_positions = Enum.sort_by(positions, fn {pos, _len} -> pos end)

    sorted_positions
    |> Enum.reduce({0, []}, fn {byte_pos, byte_len}, {last_byte_pos, segments} ->
      # Extract text before this match (includes any spaces) - using byte positions
      before_text =
        if byte_pos > last_byte_pos do
          binary_part(text, last_byte_pos, byte_pos - last_byte_pos)
        else
          ""
        end

      # Extract the matched text (preserving original case) - using byte positions
      # This is the actual matched substring from the text
      matched_text = binary_part(text, byte_pos, byte_len)

      # Build segments (only add text segment if non-empty)
      new_segments =
        segments ++
          if(byte_size(before_text) > 0, do: [{:text, before_text}], else: []) ++
          [{:link, Slug.slugify(term.name), matched_text}]

      # Update last_end to after this match (in byte positions)
      {byte_pos + byte_len, new_segments}
    end)
    |> then(fn {last_byte_pos, segments} ->
      # Add any remaining text after the last match (only if non-empty)
      text_byte_size = byte_size(text)

      if last_byte_pos < text_byte_size do
        remaining_text = binary_part(text, last_byte_pos, text_byte_size - last_byte_pos)

        if byte_size(remaining_text) > 0 do
          segments ++ [{:text, remaining_text}]
        else
          segments
        end
      else
        segments
      end
    end)
    |> Enum.filter(fn
      {:text, text} -> byte_size(text) > 0
      {:link, _, _} -> true
    end)
  end
end
