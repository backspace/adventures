defmodule Registrations.Repo.Migrations.RemoveTestPlay do
  use Ecto.Migration

  # Test play is retired in favour of staging rehearsals with the
  # event start_time reset (see landgrab-copy.sh). This removes the
  # test-session scoping from the gameplay tables:
  #
  #   * deletes test-scoped attempt/capture rows (they were private
  #     rehearsal data, never part of the real game)
  #   * drops the test_session_id columns and their check constraints
  #   * drops captures.pole_id (existed only so test-play captures of
  #     unattached puzzlets could be tied to a pole; real captures
  #     resolve the pole via the puzzlet)
  #   * replaces the partial one-capture-per-puzzlet unique index with
  #     an unconditional one, keeping the same name the Capture
  #     changeset references
  #   * tightens team_id to NOT NULL now that every row must be real
  #   * drops the test_sessions table
  #
  # Irreversible: rolled-up test data is deleted.
  def up do
    execute("DELETE FROM landgrab.attempts WHERE test_session_id IS NOT NULL")
    execute("DELETE FROM landgrab.captures WHERE test_session_id IS NOT NULL")

    execute("ALTER TABLE landgrab.attempts DROP CONSTRAINT real_attempts_have_team")
    execute("ALTER TABLE landgrab.captures DROP CONSTRAINT real_captures_have_team")

    drop(index("captures", [:puzzlet_id], name: :captures_puzzlet_test_unique, prefix: "landgrab"))
    drop(index("captures", [:puzzlet_id], name: :captures_puzzlet_real_unique, prefix: "landgrab"))
    drop(index("attempts", [:test_session_id], prefix: "landgrab"))
    drop(index("captures", [:test_session_id], prefix: "landgrab"))
    drop(index("captures", [:pole_id], prefix: "landgrab"))

    alter table("attempts", prefix: "landgrab") do
      remove(:test_session_id)
      modify(:team_id, :binary_id, null: false)
    end

    alter table("captures", prefix: "landgrab") do
      remove(:test_session_id)
      remove(:pole_id)
      modify(:team_id, :binary_id, null: false)
    end

    create(
      unique_index("captures", [:puzzlet_id],
        name: :captures_puzzlet_real_unique,
        prefix: "landgrab"
      )
    )

    drop(table("test_sessions", prefix: "landgrab"))
  end

  def down do
    raise Ecto.MigrationError, message: "test-play removal is irreversible"
  end
end
