defmodule Wortwildnis.Repo.Migrations.CatchUpMissingMigrations do
  @moduledoc """
  Brings the actual DB schema in line with what the Ash resources and their
  committed snapshots (priv/resource_snapshots) already declare. These
  changes exist in `priv/resource_snapshots/repo/{terms,reactions}/20260108145744.json`
  but no migration in `priv/repo/migrations` ever created them:

  - `terms.example` / `terms.owner_id` index / `reactions.term_id` index:
    no migration touching them exists at all — the migration that should
    have shipped alongside the snapshot update appears to have never been
    committed.
  - `terms.translation_es`: migration `20251213181709_add_translation_es_to_terms.exs`
    exists but its `change/0` body is empty (a no-op) — never edit that
    file to add the column now, since Ecto tracks migrations as
    already-applied by version, not content, so any DB where it already
    ran as a no-op would never pick up an edit to its body.

  Every statement here is written `IF NOT EXISTS` / `IF EXISTS`: prod turned
  out to already have `terms.example` (added out-of-band at some point, not
  through any committed migration), so a plain `add`/`create index` raised
  `duplicate_column`/`already_exists` and crashed the release's migration
  step. Since we can't know which of these four items are already present
  in any given environment, every one of them has to tolerate already being
  there.

  `mix ash_postgres.generate_migrations` reports "no changes detected" for
  all of these because it only diffs resources against the snapshot, not
  against the actual database, so it can't catch this on its own.
  """
  use Ecto.Migration

  def up do
    execute "ALTER TABLE terms ADD COLUMN IF NOT EXISTS example text"
    execute "ALTER TABLE terms ADD COLUMN IF NOT EXISTS translation_es text"
    execute "CREATE INDEX IF NOT EXISTS terms_owner_id_index ON terms (owner_id)"
    execute "CREATE INDEX IF NOT EXISTS reactions_term_id_index ON reactions (term_id)"
  end

  def down do
    execute "DROP INDEX IF EXISTS reactions_term_id_index"
    execute "DROP INDEX IF EXISTS terms_owner_id_index"
    execute "ALTER TABLE terms DROP COLUMN IF EXISTS translation_es"
    execute "ALTER TABLE terms DROP COLUMN IF EXISTS example"
  end
end
