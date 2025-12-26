defmodule WortwildnisWeb.ContentFilter do
  @moduledoc """
  Content filtering module for detecting potentially offensive or adult content.
  """

  @bad_words [
    "fotze",
    "neger",
    "anal",
    " stuhl",
    "hure",
    "möse",
    "nutte",
    "nougat",
    "schlampe",
    "fick",
    "vulgär",
    "arschloch",
    "menstruation",
    "sex",
    "geschlechtsorgan",
    "penis",
    "vagina",
    "erektion",
    "mumu",
    "muschi",
    "schwuchtel",
    "genital",
    "pimpern",
    "geschlechts",
    # including space
    " anal"
  ]

  @doc """
  Returns the list of words that should trigger content filtering.
  """
  def bad_words, do: @bad_words

  @doc """
  Checks if the given content is clean (does not contain any bad words).

  ## Examples

      iex> WortwildnisWeb.ContentFilter.clean?("hello world")
      true

      iex> WortwildnisWeb.ContentFilter.clean?("some bad word")
      false
  """
  def clean?(content) when is_binary(content) do
    content_lower = String.downcase(content)

    @bad_words
    |> Enum.all?(fn bad_word ->
      not String.contains?(content_lower, String.downcase(bad_word))
    end)
  end

  def clean?(_), do: true
end
