defmodule AdventureRegistrations.Repo.Migrations.AddUnmnemonicDevicesCallsPaths do
  use Ecto.Migration

  def change do
    alter table("calls", prefix: "unmnemonic_devices") do
      add(:path, :string)
    end
  end
end
