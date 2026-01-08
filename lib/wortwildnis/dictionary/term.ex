defmodule Wortwildnis.Dictionary.Term do
  import Ecto.Query
  import Ash.Expr

  use Ash.Resource,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban],
    otp_app: :wortwildnis,
    domain: Wortwildnis.Dictionary,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "terms"
    repo Wortwildnis.Repo

    identity_wheres_to_sql unique_term_of_the_day: "term_of_the_day IS NOT NULL"

    custom_indexes do
      index "lower(name)", name: "terms_lower_name_index"
      index [:owner_id]
    end
  end

  oban do
    triggers do
      trigger :find_contained_terms_job do
        # the thing to call
        action :find_contained_terms
        queue :find_contained_terms
        worker_module_name Wortwildnis.Dictionary.Term.AshOban.Worker.FindContainedTermsJob
        # once a week
        scheduler_cron "@weekly"
        scheduler_module_name Wortwildnis.Dictionary.Term.AshOban.Scheduler.FindContainedTermsJob
      end

      trigger :translate_job do
        action :translate
        queue :translate
        worker_module_name Wortwildnis.Dictionary.Term.AshOban.Worker.TranslateJob
        scheduler_cron false
        scheduler_module_name Wortwildnis.Dictionary.Term.AshOban.Scheduler.TranslateJob
      end
    end
  end

  actions do
    # Note: We don't include update: :* to prevent accidental clearing of owner_id
    defaults [:read]

    destroy :destroy do
      change cascade_destroy(:reactions)
    end

    create :create do
      accept [:name, :description, :example]
    end

    create :bulk_import do
      accept [:name, :description, :example]
    end

    create :create_term_with_owner do
      accept [:name, :description, :example]
      change relate_actor(:owner)
      change run_oban_trigger(:find_contained_terms_job)
    end

    update :update_owned_term do
      # accept means these are the args and we apply it straight away
      accept [:name, :description, :example]
      change set_attribute(:translation_en, nil)
      change set_attribute(:translation_es, nil)
      change run_oban_trigger(:find_contained_terms_job)
    end

    update :enqueue_find_contained_terms do
      change run_oban_trigger(:find_contained_terms_job)
    end

    read :search do
      argument :q, :string, allow_nil?: false

      # Filter by trigram similarity cutoff
      filter expr(
               fragment(
                 "similarity(?, ?) > 0.4",
                 name,
                 ^arg(:q)
               )
             )

      # Order by trigram similarity (desc) - using calculation

      prepare build(sort: [{calc(fragment("similarity(?, ?)", name, ^arg(:q))), :desc}])
    end

    read :by_letter do
      argument :letter, :string, allow_nil?: false

      # Filter by first letter (case-insensitive, accent-insensitive)
      filter expr(
               fragment(
                 "LOWER(unaccent(SUBSTRING(?, 1, 1))) = LOWER(unaccent(?))",
                 name,
                 ^arg(:letter)
               )
             )

      # Sort alphabetically by name
      prepare build(sort: [name: :asc])
    end

    read :user_submitted_terms do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(owner_id == ^arg(:user_id))
    end

    read :user_reacted_terms do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(exists(reactions, user_id == ^arg(:user_id)))
    end

    read :by_content do
      argument :name, :string, allow_nil?: false
      argument :description, :string, allow_nil?: false
      filter expr(name == ^arg(:name))
    end

    read :term_of_the_day do
      argument :date, :date, allow_nil?: false

      filter expr(term_of_the_day == ^arg(:date))
      get? true
    end

    read :recently_reacted do
      # Filter to only include terms that have reactions
      filter expr(exists(reactions, true))

      # Sort by the most recent reaction timestamp (descending)
      prepare build(
                sort: [
                  {calc(
                     fragment("(SELECT MAX(updated_at) FROM reactions WHERE term_id = ?)", id)
                   ), :desc}
                ]
              )
    end

    read :random do
      # Order by random and return a single result
      prepare build(sort: [{calc(fragment("random()")), :asc}], limit: 1)
      get? true
    end

    update :set_term_of_the_day do
      argument :date, :date, allow_nil?: false
      accept []
      change set_attribute(:term_of_the_day, arg(:date))
    end

    update :unset_term_of_the_day do
      accept []
      change set_attribute(:term_of_the_day, nil)
    end

    update :queue_translate do
      IO.inspect("queue_translate")
      change run_oban_trigger(:translate_job)
    end

    update :translate do
      accept [:translation_en, :translation_es]
      require_atomic? false

      change fn changeset, _context ->
        term = changeset.data
        description = term.description

        # Translate to English
        translation_en_result = DeeplEx.translate(description, :DE, :EN)

        # Translate to Spanish
        translation_es_result = DeeplEx.translate(description, :DE, :ES)

        # Handle translation results - check if they're Tesla error responses
        translation_en =
          case translation_en_result do
            {:ok, text} when is_binary(text) ->
              text

            %Tesla.Env{status: 429} = env ->
              # Rate limit - raise error so Oban can retry
              require Logger
              Logger.warning("DeepL rate limit hit for term #{term.id}, will retry")
              raise "DeepL rate limit exceeded (HTTP 429)"

            %Tesla.Env{status: status} = env when status >= 400 ->
              # Other API error - raise error so Oban can retry
              require Logger
              Logger.error("DeepL translation failed for term #{term.id}: HTTP #{status}")
              raise "DeepL API error: HTTP #{status}"

            other ->
              require Logger
              Logger.error("Unexpected DeepL response for term #{term.id}: #{inspect(other)}")
              raise "Unexpected DeepL response: #{inspect(other)}"
          end

        translation_es =
          case translation_es_result do
            {:ok, text} when is_binary(text) ->
              text

            %Tesla.Env{status: 429} = env ->
              # Rate limit - raise error so Oban can retry
              require Logger
              Logger.warning("DeepL rate limit hit for term #{term.id}, will retry")
              raise "DeepL rate limit exceeded (HTTP 429)"

            %Tesla.Env{status: status} = env when status >= 400 ->
              # Other API error - raise error so Oban can retry
              require Logger
              Logger.error("DeepL translation failed for term #{term.id}: HTTP #{status}")
              raise "DeepL API error: HTTP #{status}"

            other ->
              require Logger
              Logger.error("Unexpected DeepL response for term #{term.id}: #{inspect(other)}")
              raise "Unexpected DeepL response: #{inspect(other)}"
          end

        # Update attributes with valid translations
        changeset
        |> Ash.Changeset.change_attribute(:translation_en, translation_en)
        |> Ash.Changeset.change_attribute(:translation_es, translation_es)
      end
    end

    update :find_contained_terms do
      require_atomic? false

      change fn changeset, _context ->
        term = changeset.data
        description = term.description
        tokens = Essence.Tokenizer.tokenize(description)

        # Find all terms whose name appears in the current term's description
        # Check if name appears in description: description ILIKE '%' || name || '%'
        # We need to use Ecto query directly for this complex ILIKE pattern
        contained_terms_data =
          Wortwildnis.Repo.all(
            from t in Wortwildnis.Dictionary.Term,
              where:
                fragment(
                  "LOWER(?) = ANY(?)",
                  t.name,
                  ^Enum.map(tokens, &String.downcase/1)
                ),
              where: t.id != ^term.id,
              select: %{id: t.id, name: t.name}
          )
          |> filter_longest_subterms()

        contained_term_ids = Enum.map(contained_terms_data, & &1.id)

        # Build cache as list of maps with string keys for JSON serialization
        contained_terms_cache =
          Enum.map(contained_terms_data, fn %{id: id, name: name} ->
            %{"id" => to_string(id), "name" => name}
          end)

        # Use Ash to manage the relationships and cache the data as JSON
        changeset
        |> Ash.Changeset.change_attribute(:contained_terms_cache, contained_terms_cache)
        |> Ash.Changeset.manage_relationship(:contained_terms, contained_term_ids,
          type: :append_and_remove
        )
      end
    end
  end

  policies do
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    policy action [:update_owned_term, :destroy] do
      authorize_if relates_to_actor_via(:owner)
      # authorize_if always()
    end

    policy action [
             :translate,
             :queue_translate,
             :find_contained_terms,
             :enqueue_find_contained_terms
           ] do
      authorize_if always()
    end

    policy action [
             :read,
             :search,
             :by_letter,
             :term_of_the_day,
             :user_submitted_terms,
             :user_reacted_terms,
             :recently_reacted,
             :by_content,
             :random
           ] do
      authorize_if always()
    end

    policy action :create_term_with_owner do
      authorize_if actor_present()
    end

    policy action [:set_term_of_the_day, :unset_term_of_the_day] do
      authorize_if never()
    end

    policy action [:create, :bulk_import] do
      authorize_if never()
    end
  end

  pub_sub do
    module WortwildnisWeb.Endpoint
    prefix "terms"

    publish :translate, ["translated"]
    publish :find_contained_terms, ["contained_terms_found"]
    publish :destroy, ["destroyed"]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :description, :string do
      allow_nil? false
    end

    attribute :translation_en, :string do
      allow_nil? true
    end

    attribute :translation_es, :string do
      allow_nil? true
    end

    attribute :example, :string do
      allow_nil? true
    end

    attribute :scraped_from_mundmische, :boolean do
      allow_nil? false
      default false
    end

    attribute :term_of_the_day, :date do
      allow_nil? true
    end

    # Cached JSON array of contained term data [{id, name}, ...] for fast rendering
    # Invalidated/updated when find_contained_terms runs
    attribute :contained_terms_cache, {:array, :map} do
      allow_nil? true
      default nil
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :owner, Wortwildnis.Accounts.User do
      allow_nil? true
    end

    has_many :reactions, Wortwildnis.Social.Reaction, destination_attribute: :term_id

    many_to_many :contained_terms, Wortwildnis.Dictionary.Term do
      through Wortwildnis.Dictionary.TermContainedTerm
      source_attribute_on_join_resource :term_id
      destination_attribute_on_join_resource :contained_term_id
    end

    many_to_many :containing_terms, Wortwildnis.Dictionary.Term do
      through Wortwildnis.Dictionary.TermContainedTerm
      source_attribute_on_join_resource :contained_term_id
      destination_attribute_on_join_resource :term_id
    end
  end

  calculations do
    calculate :is_owner, :boolean, expr(owner_id == ^actor(:id))

    # Count of how many words from the normalized query appear in the normalized term name
    # Returns the number of matching words (0 to N) - terms with more matching words rank higher
    # Splits query on dashes/spaces and counts how many words appear in the term name
    calculate :contains_all_words,
              :integer,
              expr(
                fragment(
                  """
                  (
                    SELECT COUNT(*)
                    FROM unnest(string_to_array(regexp_replace(LOWER(unaccent(?)), '[\\s-]+', ' ', 'g'), ' ')) AS word
                    WHERE word != ''
                      AND regexp_replace(LOWER(unaccent(name)), '[\\s-]+', ' ', 'g') LIKE '%' || word || '%'
                  )
                  """,
                  ^arg(:q)
                )
              )

    # Name length for secondary sorting (shorter terms first, for stability)
    calculate :name_length, :integer, expr(fragment("LENGTH(?)", name))

    calculate :similarity,
              :float,
              expr(
                fragment(
                  "similarity(?, ?)",
                  name,
                  ^arg(:q)
                )
              )
  end

  identities do
    identity :unique_name_description, [:name, :description]

    identity :unique_term_of_the_day, [:term_of_the_day] do
      where expr(not is_nil(term_of_the_day))
    end
  end

  # Helper function to filter out shorter subterms when longer ones exist
  # For example, if both "ja vielleicht" and "ja" are found, keep only "ja vielleicht"
  defp filter_longest_subterms(terms) do
    terms
    |> Enum.sort_by(&String.length(&1.name), :desc)
    |> Enum.reduce([], fn term, acc ->
      # Check if this term's name is contained in any already accepted term
      is_subterm? =
        Enum.any?(acc, fn accepted_term ->
          String.contains?(accepted_term.name, term.name)
        end)

      if is_subterm? do
        acc
      else
        [term | acc]
      end
    end)
    |> Enum.reverse()
  end
end
