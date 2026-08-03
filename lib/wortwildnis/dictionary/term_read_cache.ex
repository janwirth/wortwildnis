defmodule Wortwildnis.Dictionary.TermReadCache do
  @moduledoc """
  Short-TTL read-through cache for single-term reloads.

  Every PubSub broadcast for a term change (reaction, translation, destroy)
  is handled independently by every connected LiveView process, each of
  which re-fetches the term with `standard_term_loads/0`. On a page with
  many concurrent viewers, a single reaction can fan out into one DB read
  per connected socket at the same instant.

  This cache collapses that burst into a single DB read: the term is
  fetched once with no actor (all `:read` policies for Term are
  `authorize_if always()`, so this is safe) and reused by every caller for
  `@ttl_ms`. The actor-dependent `is_owner` calculation is recomputed
  in-memory from the cached `owner_id`, since it only depends on
  `owner_id == actor.id`.
  """

  use GenServer

  alias Wortwildnis.Dictionary.Term

  @table __MODULE__
  @ttl_ms 1_500

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Fetches a term with standard loads, reusing a cached read (fetched with
  no actor) if one was taken within the last #{@ttl_ms}ms, and patching in
  the actor-specific `is_owner` field.
  """
  def get_term_with_loads(id, actor) do
    term = fetch(id)
    actor_id = actor && actor.id
    %{term | is_owner: not is_nil(actor_id) and term.owner_id == actor_id}
  end

  defp fetch(id) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, id) do
      [{^id, fetched_at, term}] when now - fetched_at < @ttl_ms ->
        term

      _ ->
        term =
          Ash.get!(Term, id,
            actor: nil,
            load: WortwildnisWeb.LiveView.TermHelpers.standard_term_loads()
          )

        :ets.insert(@table, {id, now, term})
        term
    end
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end
end
