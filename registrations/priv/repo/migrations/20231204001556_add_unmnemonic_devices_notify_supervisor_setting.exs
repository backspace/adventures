defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesNotifySupervisorSetting do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("settings", prefix: "unmnemonic_devices") do
      add(:notify_supervisor, :boolean, default: true)
    end
  end
end
