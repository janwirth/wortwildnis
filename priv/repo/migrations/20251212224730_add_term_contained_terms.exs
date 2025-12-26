defmodule Wortwildnis.Repo.Migrations.AddTermContainedTerms do
  use Ecto.Migration

  def up do
    create table(:term_contained_terms, primary_key: false) do
      add :term_id,
          references(:terms,
            column: :id,
            name: "term_contained_terms_term_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          primary_key: true,
          null: false

      add :contained_term_id,
          references(:terms,
            column: :id,
            name: "term_contained_terms_contained_term_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          primary_key: true,
          null: false
    end

    create unique_index(:term_contained_terms, [:term_id, :contained_term_id],
             name: "term_contained_terms_unique_index"
           )

    create index(:term_contained_terms, [:term_id])
    create index(:term_contained_terms, [:contained_term_id])
  end

  def down do
    drop_if_exists unique_index(:term_contained_terms, [:term_id, :contained_term_id],
                     name: "term_contained_terms_unique_index"
                   )

    drop_if_exists index(:term_contained_terms, [:contained_term_id])
    drop_if_exists index(:term_contained_terms, [:term_id])

    drop table(:term_contained_terms)
  end
end
