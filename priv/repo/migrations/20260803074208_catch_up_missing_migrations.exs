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

  `mix ash_postgres.generate_migrations` reports "no changes detected" for
  all of these because it only diffs resources against the snapshot, not
  against the actual database, so it can't catch this on its own.

  Symptom confirmed by `mix test`: any read of Term that selects `example`
  (e.g. the sitemap's `recently_reacted` query) fails with
  `(Postgrex.Error) ERROR 42703 (undefined_column) column t0.example does
  not exist`, then (once that's fixed) the same for `translation_es`. If
  this migration hasn't already been applied by some out-of-band means, run
  it before deploying.
  """
  use Ecto.Migration

  def change do
    alter table(:terms) do
      add :example, :text
      add :translation_es, :text
    end

    create index(:terms, [:owner_id])
    create index(:reactions, [:term_id])
  end
end
