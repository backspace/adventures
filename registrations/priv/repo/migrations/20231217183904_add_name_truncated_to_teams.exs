defmodule Registrations.Repo.Migrations.AddNameTruncatedToTeams do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE teams
    ADD COLUMN name_truncated VARCHAR(53) GENERATED ALWAYS AS (
        CASE
            WHEN length(name) > 50 THEN
                substring(name from 1 for 50 - position(' ' in reverse(substring(name from 1 for 50)))) || '…'
            ELSE
                name
        END
    ) STORED;
    """)
  end

  def down do
    execute("ALTER TABLE teams DROP COLUMN name_truncated;")
  end
end
