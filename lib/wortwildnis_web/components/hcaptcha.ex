defmodule WortwildnisWeb.HcaptchaComponent do
  @moduledoc """
  Renders hCaptcha widget and hidden input for form submission.
  """
  use Phoenix.Component

  def register_extra(assigns) do
    assigns = assign(assigns, :input_id, "register")

    ~H"""
    <.hcaptcha form={@form} input_id={@input_id} />
    """
  end

  def reset_extra(assigns) do
    assigns = assign(assigns, :input_id, "reset")

    ~H"""
    <.hcaptcha form={@form} input_id={@input_id} />
    """
  end

  attr :form, :any, required: true
  attr :input_id, :string, required: true

  def hcaptcha(assigns) do
    input_name = Phoenix.HTML.Form.input_name(assigns.form, :h_captcha_response)
    callback = "hcaptchaCallback#{String.replace(assigns.input_id, "-", "_")}"
    expired_callback = "hcaptchaExpiredCallback#{String.replace(assigns.input_id, "-", "_")}"
    public_key = resolve_public_key(Application.get_env(:hcaptcha, :public_key))

    assigns =
      assigns
      |> assign(:input_name, input_name)
      |> assign(:callback, callback)
      |> assign(:expired_callback, expired_callback)
      |> assign(:public_key, public_key)

    ~H"""
    <div
      id={"hcaptcha-#{@input_id}"}
      phx-update="ignore"
      phx-hook=".Hcaptcha"
      class="my-2"
      data-callback={@callback}
      data-expired-callback={@expired_callback}
      data-input-id={"hcaptcha-input-#{@input_id}"}
    >
      <input
        type="hidden"
        name={@input_name}
        id={"hcaptcha-input-#{@input_id}"}
        value=""
      />
      <div phx-no-copy class="[&_.h-captcha]:min-h-[78px]">
        <script src="https://js.hcaptcha.com/1/api.js" async defer>
        </script>
        <div
          class="h-captcha"
          data-sitekey={@public_key}
          data-callback={@callback}
          data-expired-callback={@expired_callback}
        >
        </div>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Hcaptcha">
      export default {
        mounted() {
          const callback = this.el.dataset.callback;
          const expiredCallback = this.el.dataset.expiredCallback;
          const inputId = this.el.dataset.inputId;
          const form = this.el.closest('form');
          const submitBtn = form?.querySelector('[type="submit"]');

          if (submitBtn) submitBtn.disabled = true;

          const preventIfNoCaptcha = (e) => {
            const input = document.getElementById(inputId);
            if (!input?.value) {
              e.stopImmediatePropagation();
              e.preventDefault();
            }
          };
          form?.addEventListener('submit', preventIfNoCaptcha, true);
          this._preventIfNoCaptcha = preventIfNoCaptcha;
          this._form = form;

          window[callback] = (token) => {
            const input = document.getElementById(inputId);
            if (input) input.value = token;
            if (submitBtn) submitBtn.disabled = false;
          };

          window[expiredCallback] = () => {
            const input = document.getElementById(inputId);
            if (input) input.value = '';
            if (submitBtn) submitBtn.disabled = true;
          };
        },
        destroyed() {
          const callback = this.el.dataset.callback;
          const expiredCallback = this.el.dataset.expiredCallback;
          if (this._form && this._preventIfNoCaptcha) {
            this._form.removeEventListener('submit', this._preventIfNoCaptcha, true);
          }
          delete window[callback];
          delete window[expiredCallback];
        }
      }
    </script>
    """
  end

  defp resolve_public_key({:system, env_var}) when is_binary(env_var) do
    System.get_env(env_var) || ""
  end

  defp resolve_public_key(key) when is_binary(key), do: key
  defp resolve_public_key(_), do: ""
end
