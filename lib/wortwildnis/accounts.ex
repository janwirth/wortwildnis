defmodule Wortwildnis.Accounts do
  use Ash.Domain,
    otp_app: :wortwildnis,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Wortwildnis.Accounts.Token
    resource Wortwildnis.Accounts.User
  end
end
