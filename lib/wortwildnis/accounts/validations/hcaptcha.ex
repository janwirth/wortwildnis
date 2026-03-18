defmodule Wortwildnis.Accounts.Validations.Hcaptcha do
  @moduledoc """
  Validates hCaptcha response for bot protection on sign up and password reset.
  """
  use Ash.Resource.Validation

  @impl true
  def supports(_opts), do: [Ash.Changeset, Ash.ActionInput]

  @impl true
  def validate(changeset_or_input, _opts, _context) do
    response =
      case changeset_or_input do
        %Ash.Changeset{} ->
          Ash.Changeset.get_argument(changeset_or_input, :h_captcha_response)

        %Ash.ActionInput{} ->
          Ash.ActionInput.get_argument(changeset_or_input, :h_captcha_response)
      end

    case Hcaptcha.verify(response || "") do
      {:ok, _} ->
        :ok

      {:error, _errors} ->
        {:error, [field: :h_captcha_response, message: "Verification failed. Please try again."]}
    end
  end
end
