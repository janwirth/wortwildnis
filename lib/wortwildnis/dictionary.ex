defmodule Wortwildnis.Dictionary do
  use Ash.Domain, otp_app: :wortwildnis, extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource Wortwildnis.Dictionary.Term
    resource Wortwildnis.Dictionary.TermContainedTerm
  end
end
