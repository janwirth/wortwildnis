defmodule Wortwildnis.Accounts.User.Role do
  use Ash.Type.Enum, values: [:user, :admin, :moderator]
end
