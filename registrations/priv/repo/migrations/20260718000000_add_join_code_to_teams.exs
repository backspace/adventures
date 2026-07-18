defmodule Registrations.Repo.Migrations.AddJoinCodeToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add(:join_code, :string)
    end

    # Backfill existing teams so every team is joinable by code, not just
    # ones created after this migration. Opaque 6-char code; the app-side
    # generator (Team.changeset) uses an unambiguous alphabet, but for the
    # backfill any unique string is fine.
    execute(
      "UPDATE teams SET join_code = upper(substr(md5(random()::text || id::text), 1, 6)) WHERE join_code IS NULL",
      ""
    )

    create(unique_index(:teams, [:join_code]))
  end
end
