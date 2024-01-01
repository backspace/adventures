defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesRecordingsCalls do
  use Ecto.Migration

  def change do
    alter table("recordings", prefix: "unmnemonic_devices") do
      add(:call_id, references("calls", prefix: "unmnemonic_devices", type: :string))
    end
  end
end
