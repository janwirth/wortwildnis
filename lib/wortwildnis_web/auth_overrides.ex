defmodule WortwildnisWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, "/images/logo_w.webp"
    set :dark_image_url, "/images/logo_w.webp"
  end
end
