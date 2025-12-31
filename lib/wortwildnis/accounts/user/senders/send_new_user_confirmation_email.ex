defmodule Wortwildnis.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends an email for a new user to confirm their email address.
  """

  use AshAuthentication.Sender
  use WortwildnisWeb, :verified_routes

  import Swoosh.Email

  alias Wortwildnis.Mailer

  @impl true
  def send(user, token, _) do
    new()
    # TODO: Replace with your email
    |> from({"Jan", "info@wortwildnis.de"})
    |> to(to_string(user.email))
    |> subject("Wortwildnis - Bestätige deine E-Mail-Adresse")
    |> html_body(body(token: token))
    |> Mailer.deliver!()
  end

  defp body(params) do
    url = url(~p"/confirm_new_user/#{params[:token]}")

    """
    <p>Klicke auf den folgenden Link, um deine E-Mail-Adresse zu bestätigen:</p>
    <p><a href="#{url}">#{url}</a></p>
    """
  end
end
