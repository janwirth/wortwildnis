defmodule WortwildnisWeb.DateFormatter do
  @moduledoc """
  Utility module for formatting dates and times.
  """

  @doc """
  Formats a DateTime into a relative time string in German.

  Returns an empty string if the datetime is nil.

  ## Examples

      iex> format_relative_time(~U[2024-01-01 12:00:00Z])
      "vor X Jahren"

      iex> format_relative_time(nil)
      ""
  """
  def format_relative_time(datetime) when is_nil(datetime), do: ""

  def format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds == 0 -> "gerade"
      diff_seconds < 45 -> "vor wenigen Sekunden"
      diff_seconds < 90 -> "vor einer Minute"
      diff_seconds < 2700 -> "vor #{div(diff_seconds, 60)} Minuten"
      diff_seconds < 5400 -> "vor einer Stunde"
      diff_seconds < 79200 -> "vor #{div(diff_seconds, 3600)} Stunden"
      diff_seconds < 129_600 -> "vor einem Tag"
      diff_seconds < 2_160_000 -> "vor #{div(diff_seconds, 86400)} Tagen"
      diff_seconds < 3_888_000 -> "vor einem Monat"
      diff_seconds < 29_808_000 -> "vor #{div(diff_seconds, 2_592_000)} Monaten"
      diff_seconds < 47_088_000 -> "vor einem Jahr"
      true -> "vor #{div(diff_seconds, 31_536_000)} Jahren"
    end
  end
end
