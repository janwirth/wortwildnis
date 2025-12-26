defmodule Wortwildnis.Social do
  use Ash.Domain,
    otp_app: :wortwildnis,
    extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource Wortwildnis.Social.Reaction
  end
end
