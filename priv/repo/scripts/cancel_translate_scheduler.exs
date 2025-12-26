# Script to cancel the persistent TranslateJob scheduler
alias Wortwildnis.Repo
import Ecto.Query

IO.puts("\n=== Cancelling TranslateJob Scheduler ===\n")

# Find the specific scheduler job for TranslateJob
scheduler_jobs =
  from(j in "oban_jobs",
    where: fragment("? LIKE ?", j.worker, "%Scheduler.TranslateJob%"),
    select: %{
      id: j.id,
      state: j.state,
      worker: j.worker,
      queue: j.queue,
      inserted_at: j.inserted_at
    }
  )
  |> Repo.all()

if Enum.empty?(scheduler_jobs) do
  IO.puts("✅ No TranslateJob scheduler jobs found!")
else
  IO.puts("Found #{length(scheduler_jobs)} TranslateJob scheduler job(s):\n")

  Enum.each(scheduler_jobs, fn job ->
    IO.puts("  - [#{job.state}] #{job.worker} (ID: #{job.id})")
    IO.puts("    Queue: #{job.queue}")
    IO.puts("    Inserted: #{job.inserted_at}")
  end)

  IO.puts("\nCancelling TranslateJob scheduler job(s)...")

  {cancelled_count, _} =
    from(j in "oban_jobs",
      where: fragment("? LIKE ?", j.worker, "%Scheduler.TranslateJob%")
    )
    |> Repo.delete_all()

  IO.puts("✅ Deleted #{cancelled_count} scheduler job(s)!")
end

# Also cancel any pending Worker.TranslateJob jobs
IO.puts("\n=== Cancelling Pending TranslateJob Worker Jobs ===\n")

translate_worker_jobs =
  from(j in "oban_jobs",
    where: fragment("? LIKE ?", j.worker, "%Worker.TranslateJob%"),
    where: j.state in ["available", "scheduled"],
    select: %{count: count(j.id)}
  )
  |> Repo.one()

if translate_worker_jobs.count == 0 do
  IO.puts("✅ No pending translate worker jobs found!")
else
  IO.puts("Found #{translate_worker_jobs.count} pending translate worker jobs\n")

  {cancelled_count, _} =
    from(j in "oban_jobs",
      where: fragment("? LIKE ?", j.worker, "%Worker.TranslateJob%"),
      where: j.state in ["available", "scheduled"]
    )
    |> Repo.update_all(set: [state: "cancelled"])

  IO.puts("✅ Cancelled #{cancelled_count} pending translate worker job(s)!")
end

IO.puts("\n✅ Done! All TranslateJob scheduler and pending worker jobs have been handled.\n")




