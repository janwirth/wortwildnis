defmodule Wortwildnis.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender
  use WortwildnisWeb, :verified_routes

  import Swoosh.Email

  alias Wortwildnis.Mailer

  @impl true
  def send(user, token, _) do
    new()
    |> from({"Jan", "info@wortwildnis.de"})
    |> to(to_string(user.email))
    |> subject("Wortwildnis - Passwort zurücksetzen")
    |> html_body(body(token: token))
    |> Mailer.deliver!()
  end

  defp body(params) do
    url = url(~p"/password-reset/#{params[:token]}")

    """
    <p>Klicke auf den folgenden Link, um dein Passwort zurückzusetzen:</p>
    <p><a href="#{url}">#{url}</a></p>
    """
  end
end
