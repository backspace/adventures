defmodule AdventureRegistrations.Repo.Migrations.RemoveUnusedUnmnemonicDevicesSettings do
  use Ecto.Migration

  def change do
    alter table("settings", prefix: "unmnemonic_devices") do
      remove(:day_before, :boolean, default: false)
      remove(:degrading, :boolean, default: false)
      remove(:down, :boolean, default: false)
    end
  end
end
