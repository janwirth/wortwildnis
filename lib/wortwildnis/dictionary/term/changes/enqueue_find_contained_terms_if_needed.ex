defmodule Wortwildnis.Dictionary.Term.Changes.EnqueueFindContainedTermsIfNeeded do
  @moduledoc """
  Custom change to only enqueue find_contained_terms job when needed.

  Only enqueues the job if:
  1. Cache is empty/nil (new term or cache not yet populated)
  2. Description changed (which would invalidate existing cache)

  This optimization prevents unnecessary job enqueueing when terms are updated
  but the contained_terms_cache is already populated and the description hasn't changed.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    # Determine if we should enqueue the job
    should_enqueue =
      if changeset.action_type == :create do
        # For creates, always enqueue since cache is nil
        IO.puts("EnqueueFindContainedTermsIfNeeded: CREATE action - will enqueue")
        true
      else
        # For updates, check if cache is empty or description changed
        # We need to check the original data since changeset might not have it set yet
        original_cache = Map.get(changeset.data, :contained_terms_cache)
        cache_is_empty = is_nil(original_cache) || original_cache == []

        description_changed = Ash.Changeset.changing_attribute?(changeset, :description)

        will_enqueue = cache_is_empty || description_changed
        IO.puts("EnqueueFindContainedTermsIfNeeded: UPDATE action - cache_empty: #{cache_is_empty}, desc_changed: #{description_changed}, will_enqueue: #{will_enqueue}")
        will_enqueue
      end

    # Use after_action to enqueue the job after the term is saved
    Ash.Changeset.after_action(changeset, fn _changeset_in_hook, result ->
      if should_enqueue do
        IO.puts("EnqueueFindContainedTermsIfNeeded: Enqueueing job for term #{result.id}")
        # Enqueue the job using the Oban worker
        %{
          "oban_triggered" => true,
          "primary_key" => %{"id" => result.id}
        }
        |> Wortwildnis.Dictionary.Term.AshOban.Worker.FindContainedTermsJob.new()
        |> Oban.insert()
      else
        IO.puts("EnqueueFindContainedTermsIfNeeded: Skipping job for term #{result.id} (cache already populated)")
      end

      {:ok, result}
    end)
  end
end
