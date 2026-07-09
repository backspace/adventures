defmodule Registrations.Repo.Migrations.AddPoleIdToCaptures do
  use Ecto.Migration

  def change do
    # Test-play captures happen against unattached puzzlets (no
    # `puzzlets.pole_id`) that get virtually assigned to a scanned
    # pole via `test_active_puzzlet`. Without recording *which* pole
    # was scanned, we can't later say "this pole is captured" for the
    # test-play map. This column bridges that gap. Nullable because
    # real-game captures continue to resolve the pole via the
    # puzzlet's own `pole_id`.
    alter table("captures", prefix: "landgrab") do
      add(:pole_id, references("poles",
        prefix: "landgrab",
        type: :binary_id,
        on_delete: :nothing
      ))
    end

    create(index("captures", [:pole_id], prefix: "landgrab"))
  end
end
