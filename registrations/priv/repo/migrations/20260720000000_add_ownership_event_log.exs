defmodule Registrations.Repo.Migrations.AddOwnershipEventLog do
  use Ecto.Migration

  @prefix "landgrab"

  # Generalise the immutable one-row-per-puzzlet `captures` table into a
  # kind-tagged, newest-wins ownership-event log — the shared foundation for
  # accessibility's accommodation claim, the conspiracy uncapture, and the
  # relief valve. Step 4 is behaviour-identical (only `capture` events exist);
  # the new columns/constraint are laid so those features don't re-migrate.
  def up do
    rename(table(:captures, prefix: @prefix), to: table(:ownership_events, prefix: @prefix))

    alter table(:ownership_events, prefix: @prefix) do
      # "capture" now; later "liberate" (ownership → no-one) / "accommodation"
      # (claim without solving).
      add(:kind, :string, null: false, default: "capture")
      # Set on pole-only events (liberate/accommodation) that reference no
      # puzzlet. Null on captures — their pole is derived via the puzzlet.
      add(:pole_id, :binary_id)
      # Pole-only events carry no puzzlet; liberation carries no team.
      modify(:puzzlet_id, :binary_id, null: true)
      modify(:team_id, :binary_id, null: true)
    end

    # Relax the strict one-capture-per-puzzlet rule to per-(puzzlet, team): the
    # relief valve lets many teams each solve a puzzlet (once). Normal-mode
    # "one capture per puzzlet globally" is now enforced in application code
    # (see Landgrab.insert_capture).
    drop(
      index(:ownership_events, [:puzzlet_id],
        name: :captures_puzzlet_real_unique,
        prefix: @prefix
      )
    )

    create(
      unique_index(:ownership_events, [:puzzlet_id, :team_id],
        name: :ownership_events_puzzlet_team_unique,
        where: "puzzlet_id IS NOT NULL",
        prefix: @prefix
      )
    )

    create(index(:ownership_events, [:pole_id], prefix: @prefix))
  end

  def down do
    drop(index(:ownership_events, [:pole_id], prefix: @prefix))

    drop(
      index(:ownership_events, [:puzzlet_id, :team_id],
        name: :ownership_events_puzzlet_team_unique,
        prefix: @prefix
      )
    )

    create(
      unique_index(:ownership_events, [:puzzlet_id],
        name: :captures_puzzlet_real_unique,
        prefix: @prefix
      )
    )

    alter table(:ownership_events, prefix: @prefix) do
      remove(:kind)
      remove(:pole_id)
      modify(:puzzlet_id, :binary_id, null: false)
      modify(:team_id, :binary_id, null: false)
    end

    rename(table(:ownership_events, prefix: @prefix), to: table(:captures, prefix: @prefix))
  end
end
