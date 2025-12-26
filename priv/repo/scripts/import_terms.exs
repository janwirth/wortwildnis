# Script to import terms from EdgeDB to PostgreSQL
# Usage: mix run priv/repo/scripts/import_terms.exs [limit]
# Example: mix run priv/repo/scripts/import_terms.exs 100

alias Wortwildnis.Dictionary.TermImport

limit = case System.argv() do
  [limit_str] -> String.to_integer(limit_str)
  [] -> 10
  _ ->
    IO.puts("Usage: mix run priv/repo/scripts/import_terms.exs [limit]")
    System.halt(1)
end

IO.puts("\n=== Importing #{limit} terms from EdgeDB ===\n")

case TermImport.import_terms(limit: limit, return_records?: false, return_errors?: true) do
  {:ok, result} ->
    IO.puts("✅ Import completed successfully!")
    IO.puts("  Created: #{result.created_count}")
    IO.puts("  Skipped (already exist): #{result.skipped_count}")
    IO.puts("  Total processed: #{result.total_processed}")

    if result.errors && length(result.errors) > 0 do
      IO.puts("\n⚠️  Errors encountered:")
      Enum.each(result.errors, fn error ->
        IO.puts("  - #{inspect(error)}")
      end)
    end

    IO.puts("")

  {:error, reason} ->
    IO.puts("❌ Import failed: #{inspect(reason)}")
    System.halt(1)
end
