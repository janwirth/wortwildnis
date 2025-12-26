defmodule Wortwildnis.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Wortwildnis.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:wortwildnis, :token_signing_secret)
  end
end
