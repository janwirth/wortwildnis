defmodule Wortwildnis.Dictionary.TermContainedTerm do
  use Ash.Resource,
    otp_app: :wortwildnis,
    domain: Wortwildnis.Dictionary,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "term_contained_terms"
    repo Wortwildnis.Repo
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  relationships do
    belongs_to :term, Wortwildnis.Dictionary.Term do
      primary_key? true
      allow_nil? false
    end

    belongs_to :contained_term, Wortwildnis.Dictionary.Term do
      primary_key? true
      allow_nil? false
    end
  end

  identities do
    identity :unique_term_contained_term, [:term_id, :contained_term_id]
  end
end
