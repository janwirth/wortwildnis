# Script to delete all Oban-related data
alias Wortwildnis.Repo
import Ecto.Query

IO.puts("\n=== Deleting All Oban Data ===\n")

# Helper to delete from table if it exists
delete_from_table = fn table_name ->
  try do
    {deleted, _} =
      from(t in table_name)
      |> Repo.delete_all()

    IO.puts("✅ Deleted #{deleted} row(s) from #{table_name}")
    deleted
  rescue
    Postgrex.Error ->
      IO.puts("⚠️  Table #{table_name} does not exist, skipping")
      0
  end
end

# Delete all jobs
delete_from_table.("oban_jobs")

# Delete all producers (schedulers)
delete_from_table.("oban_producers")

# Delete all peers
delete_from_table.("oban_peers")

IO.puts("\n✅ Done! All Oban data has been deleted.\n")
