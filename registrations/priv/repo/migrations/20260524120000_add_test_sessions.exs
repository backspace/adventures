defmodule Registrations.Repo.Migrations.AddTestSessions do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:test_sessions, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :creator_id,
        references(:users, type: :uuid, prefix: "public", on_delete: :nilify_all),
        null: false
      )

      add(:name, :string)
      add(:ended_at, :utc_datetime)

      timestamps()
    end

    create(index(:test_sessions, [:creator_id], prefix: "poles"))

    # Add the scope-flag columns. Real rows have test_session_id = NULL;
    # test-play rows point at a session.
    alter table(:attempts, prefix: "poles") do
      add(
        :test_session_id,
        references(:test_sessions, type: :uuid, prefix: "poles", on_delete: :delete_all)
      )

      # Allow nil team_id for test-play attempts; real attempts still require
      # it via the check constraint below.
      modify(:team_id, references(:teams, type: :uuid, prefix: "public", on_delete: :nilify_all),
        null: true,
        from: references(:teams, type: :uuid, prefix: "public", on_delete: :nilify_all)
      )
    end

    alter table(:captures, prefix: "poles") do
      add(
        :test_session_id,
        references(:test_sessions, type: :uuid, prefix: "poles", on_delete: :delete_all)
      )

      modify(:team_id, references(:teams, type: :uuid, prefix: "public", on_delete: :nilify_all),
        null: true,
        from: references(:teams, type: :uuid, prefix: "public", on_delete: :nilify_all)
      )
    end

    # Real-game attempts and captures must have a team. Test-play rows have
    # a test_session_id instead. Database-level safety so neither shape can
    # be persisted in the wrong form.
    create(
      constraint(:attempts, :real_attempts_have_team,
        prefix: "poles",
        check: "(team_id IS NOT NULL) OR (test_session_id IS NOT NULL)"
      )
    )

    create(
      constraint(:captures, :real_captures_have_team,
        prefix: "poles",
        check: "(team_id IS NOT NULL) OR (test_session_id IS NOT NULL)"
      )
    )

    # Replace the captures unique-on-puzzlet_id constraint with two partial
    # unique indexes: one for real captures, one per-test-session. This is
    # the structural defense: a real game and any number of test sessions
    # can each independently capture the same puzzlet, but only once each.
    drop_if_exists(
      index(:captures, [:puzzlet_id], unique: true, prefix: "poles")
    )

    create(
      index(:captures, [:puzzlet_id],
        unique: true,
        prefix: "poles",
        where: "test_session_id IS NULL",
        name: :captures_puzzlet_real_unique
      )
    )

    create(
      index(:captures, [:puzzlet_id, :test_session_id],
        unique: true,
        prefix: "poles",
        where: "test_session_id IS NOT NULL",
        name: :captures_puzzlet_test_unique
      )
    )

    create(index(:attempts, [:test_session_id], prefix: "poles"))
    create(index(:captures, [:test_session_id], prefix: "poles"))
  end
end
