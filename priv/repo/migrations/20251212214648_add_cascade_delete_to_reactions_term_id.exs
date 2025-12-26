defmodule Wortwildnis.Repo.Migrations.AddCascadeDeleteToReactionsTermId do
  use Ecto.Migration

  def up do
    drop constraint(:reactions, "reactions_term_id_fkey")

    execute """
    ALTER TABLE reactions
    ADD CONSTRAINT reactions_term_id_fkey
    FOREIGN KEY (term_id)
    REFERENCES terms(id)
    ON DELETE CASCADE
    """
  end

  def down do
    drop constraint(:reactions, "reactions_term_id_fkey")

    execute """
    ALTER TABLE reactions
    ADD CONSTRAINT reactions_term_id_fkey
    FOREIGN KEY (term_id)
    REFERENCES terms(id)
    """
  end
end
