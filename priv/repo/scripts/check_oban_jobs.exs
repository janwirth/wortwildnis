# Script to check Oban jobs
alias Wortwildnis.Repo
import Ecto.Query

IO.puts("\n=== Oban Jobs Status ===\n")

# Check recent jobs
recent_jobs =
  from(j in "oban_jobs",
    order_by: [desc: j.inserted_at],
    limit: 10,
    select: %{
      id: j.id,
      state: j.state,
      worker: j.worker,
      queue: j.queue,
      inserted_at: j.inserted_at,
      attempted_at: j.attempted_at,
      errors: j.errors
    }
  )
  |> Repo.all()

if Enum.empty?(recent_jobs) do
  IO.puts("❌ No jobs found in oban_jobs table!")
else
  IO.puts("Found #{length(recent_jobs)} recent jobs:\n")

  Enum.each(recent_jobs, fn job ->
    state_emoji = case job.state do
      "available" -> "⏳"
      "executing" -> "🔄"
      "completed" -> "✅"
      "discarded" -> "❌"
      "retryable" -> "🔄"
      "scheduled" -> "📅"
      _ -> "❓"
    end

    IO.puts("#{state_emoji} [#{job.state}] #{job.worker}")
    IO.puts("   Queue: #{job.queue}")
    IO.puts("   Inserted: #{job.inserted_at}")
    if job.attempted_at, do: IO.puts("   Attempted: #{job.attempted_at}")
    if job.errors && length(job.errors) > 0 do
      IO.puts("   Errors: #{inspect(job.errors)}")
    end
    IO.puts("")
  end)
end

# Count by state
counts =
  from(j in "oban_jobs",
    group_by: j.state,
    select: {j.state, count(j.id)}
  )
  |> Repo.all()
  |> Enum.into(%{})

IO.puts("\n=== Job Counts by State ===")
Enum.each(counts, fn {state, count} -> IO.puts("  #{state}: #{count}") end)

# Check for translation jobs specifically
translation_jobs =
  from(j in "oban_jobs",
    where: fragment("? LIKE ?", j.worker, "%TranslateJob%"),
    order_by: [desc: j.inserted_at],
    limit: 5,
    select: %{
      id: j.id,
      state: j.state,
      worker: j.worker,
      queue: j.queue,
      inserted_at: j.inserted_at,
      attempted_at: j.attempted_at,
      errors: j.errors
    }
  )
  |> Repo.all()

if Enum.empty?(translation_jobs) do
  IO.puts("\n⚠️  No translation jobs found!")
else
  IO.puts("\n=== Translation Jobs ===")
  Enum.each(translation_jobs, fn job ->
    IO.puts("  State: #{job.state}, Inserted: #{job.inserted_at}")
    if job.errors && length(job.errors) > 0 do
      IO.puts("  Errors: #{inspect(job.errors)}")
    end
  end)
end






