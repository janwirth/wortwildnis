defmodule WortwildnisWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, "/images/logo_w.webp"
    set :dark_image_url, "/images/logo_w.webp"
  end

  override AshAuthentication.Phoenix.Components.Password do
    set :register_form_module, WortwildnisWeb.Auth.RegisterFormWithHcaptcha
    set :reset_form_module, WortwildnisWeb.Auth.ResetFormWithHcaptcha
  end

  override AshAuthentication.Phoenix.Components.Password.Input do
    set :submit_class,
        "btn btn-block mt-4 mb-4 bg-blue-600 text-white border-none hover:opacity-90 disabled:opacity-50"
  end

  override AshAuthentication.Phoenix.Components.Confirm.Input do
    set :submit_class,
        "btn btn-block mt-4 mb-4 bg-blue-600 text-white border-none hover:opacity-90 disabled:opacity-50"
  end

  override AshAuthentication.Phoenix.Components.MagicLink.Input do
    set :submit_class,
        "btn btn-block mt-4 mb-4 bg-blue-600 text-white border-none hover:opacity-90 disabled:opacity-50"
  end
end
