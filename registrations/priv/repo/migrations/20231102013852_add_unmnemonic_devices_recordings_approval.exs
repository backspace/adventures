defmodule AdventureRegistrations.Repo.Migrations.AddUnmnemonicDevicesRecordingsApproveAndListens do
  use Ecto.Migration

  def change do
    alter table("recordings", prefix: "unmnemonic_devices") do
      add(:approved, :boolean, default: false)
      add(:team_listen_ids, {:array, :uuid}, default: [])
      add(:created_at, :utc_datetime, default: "now()")
    end
  end
end
