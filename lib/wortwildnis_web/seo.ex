defmodule WortwildnisWeb.SEO do
  @moduledoc """
  SEO configuration module for Wortwildnis.

  Provides default SEO settings with German language support.
  """
  use WortwildnisWeb, :verified_routes

  use SEO,
    json_library: Jason,
    site: &__MODULE__.site_config/1,
    open_graph:
      SEO.OpenGraph.build(
        description: "Wortwildnis - Ein Wörterbuch für deutsche Begriffe und Slang",
        site_name: "Wortwildnis",
        locale: "de_DE"
      ),
    twitter: SEO.Twitter.build(card: :summary)

  def site_config(_conn) do
    SEO.Site.build(
      default_title: "Wortwildnis",
      description: "Wortwildnis - Ein Wörterbuch für deutsche Begriffe und Slang",
      title_suffix: " · Wortwildnis",
      theme_color: "#000000",
      windows_tile_color: "#000000",
      mask_icon_color: "#000000"
    )
  end
end
