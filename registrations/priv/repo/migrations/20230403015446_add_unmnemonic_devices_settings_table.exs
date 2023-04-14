defmodule AdventureRegistrations.Repo.Migrations.AddUnmnemonicDevicesSettingsTable do
  use Ecto.Migration

  def change do
    create table("settings", prefix: "unmnemonic_devices") do
      add(:override, :text)
      add(:begun, :boolean, default: false)
      add(:compromised, :boolean, default: false)
      add(:ending, :boolean, default: false)
      add(:down, :boolean, default: false)

      timestamps()
    end
  end
end
