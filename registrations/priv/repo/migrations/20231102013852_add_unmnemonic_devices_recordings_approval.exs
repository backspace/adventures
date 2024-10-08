defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesRecordingsApproveAndListens do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("recordings", prefix: "unmnemonic_devices") do
      add(:approved, :boolean, default: false)
      add(:team_listen_ids, {:array, :uuid}, default: [])
      add(:inserted_at, :utc_datetime, default: fragment("now()"))
    end
  end
end
