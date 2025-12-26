# Script to delete all terms from the database
# Usage: mix run priv/repo/scripts/clean_terms.exs [--confirm]
# WARNING: This is a destructive operation that cannot be undone!

alias Wortwildnis.Dictionary.Term
alias Wortwildnis.Repo
import Ecto.Query

# Check for confirmation flag
args = System.argv()
confirm_flag = "--confirm" in args

unless confirm_flag do
  IO.puts("""
  ⚠️  WARNING: This script will DELETE ALL TERMS from the database!

  This operation cannot be undone. All terms and their associated reactions will be permanently deleted.

  To proceed, run:
    mix run priv/repo/scripts/clean_terms.exs --confirm
  """)
  System.halt(1)
end

IO.puts("\n=== Cleaning all terms from database ===\n")

# Count terms before deletion
term_count = Ash.read!(Term) |> length()
IO.puts("Found #{term_count} terms to delete.")

if term_count == 0 do
  IO.puts("✅ No terms to delete. Database is already clean.")
  System.halt(0)
end

# Confirm one more time
IO.puts("\n⚠️  About to delete #{term_count} terms. This cannot be undone!")
IO.puts("Press Ctrl+C within 5 seconds to cancel...")
Process.sleep(5000)

IO.puts("\nStarting deletion...")

# Delete all terms using Ecto for efficiency
# This bypasses Ash policies and is faster for bulk operations
{deleted_count, _} =
  try do
    Repo.delete_all(from(t in Term))
  rescue
    e ->
      IO.puts("  ❌ Error during deletion: #{inspect(e)}")
      {0, nil}
  end

IO.puts("\n✅ Cleanup completed!")
IO.puts("  Deleted: #{deleted_count} terms")
IO.puts("")

