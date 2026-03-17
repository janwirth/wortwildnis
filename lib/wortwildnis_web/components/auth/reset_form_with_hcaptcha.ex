defmodule WortwildnisWeb.Auth.ResetFormWithHcaptcha do
  @moduledoc """
  Wraps the default ResetForm and injects hCaptcha.
  """
  use AshAuthentication.Phoenix.Web, :live_component

  alias AshAuthentication.Phoenix.Components.Password
  import WortwildnisWeb.HcaptchaComponent, only: [hcaptcha: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.live_component
        :let={form}
        module={Password.ResetForm}
        id={@id}
        strategy={@strategy}
        label={@label}
        overrides={@overrides}
        current_tenant={@current_tenant}
        context={@context}
        auth_routes_prefix={@auth_routes_prefix}
        gettext_fn={@gettext_fn}
      >
        <div class="my-4">
          <.hcaptcha form={form} input_id="reset" />
        </div>
        {render_slot(@inner_block, form)}
      </.live_component>
    </div>
    """
  end
end
