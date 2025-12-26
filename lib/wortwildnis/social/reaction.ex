defmodule Wortwildnis.Social.Reaction do
  use Ash.Resource,
    otp_app: :wortwildnis,
    domain: Wortwildnis.Social,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "reactions"
    repo Wortwildnis.Repo

    custom_indexes do
      index [:term_id]
    end
  end

  actions do
    defaults [:read, :destroy, update: :*]

    create :react do
      accept [:reaction_type, :term_id]
      upsert? true
      upsert_identity :unique_reaction
      change relate_actor(:user)
    end

    destroy :remove_reaction do
      accept [:reaction_type, :term_id]
      change set_attribute(:user_id, nil)
    end
  end

  pub_sub do
    module WortwildnisWeb.Endpoint
    prefix "reactions"

    publish :react, ["changed"]
    publish :destroy, ["changed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :reaction_type, :atom,
      constraints: [one_of: [:up, :down, :laugh, :sad, :angry, :surprised, :confused, :thinking]]

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Wortwildnis.Accounts.User, primary_key?: true, allow_nil?: false
    belongs_to :term, Wortwildnis.Dictionary.Term, primary_key?: true, allow_nil?: false
  end

  calculations do
    calculate :is_owner, :boolean, expr(user_id == ^actor(:id))
  end

  identities do
    identity :unique_reaction, [:user_id, :term_id, :reaction_type]
  end
end
