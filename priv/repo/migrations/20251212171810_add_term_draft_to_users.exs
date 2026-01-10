defmodule Wortwildnis.Repo.Migrations.AddTermDraftToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :term_draft, :map
    end
  end

  def down do
    alter table(:users) do
      remove :term_draft
    end
  end
end
