defmodule WortwildnisWeb.AuthGettext do
  @moduledoc """
  Custom gettext helper for AshAuthentication Phoenix that handles both
  string msgids and {msgid, opts} tuples (Ecto/validation error format).
  """
  @domain "auth"

  @doc """
  Translates msgid using the auth domain. Handles both:
  - String msgids: "Sign in", "Email", etc.
  - Tuple msgids: {"is invalid", []} from form validation errors
  """
  def translate(msgid, bindings \\ [])

  def translate({msgid, opts}, _bindings) when is_binary(msgid) do
    Gettext.dgettext(WortwildnisWeb.Gettext, @domain, msgid, opts || [])
  end

  def translate(msgid, bindings) when is_binary(msgid) do
    Gettext.dgettext(WortwildnisWeb.Gettext, @domain, msgid, bindings || [])
  end

  def translate(other, _bindings) do
    to_string(other)
  end
end
