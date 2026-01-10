defmodule Wortwildnis.Dictionary.FindContainedTermsDailyJob do
  @moduledoc """
  Daily Oban job that enqueues find_contained_terms jobs for all terms.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(_job) do
    # Read all terms
    terms = Ash.read!(Wortwildnis.Dictionary.Term)

    # Directly enqueue Oban jobs instead of calling Ash.update to avoid scheduler re-enqueuing
    jobs =
      Enum.map(terms, fn term ->
        %{
          worker: Wortwildnis.Dictionary.Term.AshOban.Worker.FindContainedTermsJob,
          args: %{"id" => term.id},
          queue: :default
        }
      end)

    Oban.insert_all(jobs)

    :ok
  end
end
