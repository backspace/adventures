defmodule AdventureRegistrations.Repo.Migrations.CreateUnmnemonicDevicesRegions do
  use Ecto.Migration

  def change do
    create table(:regions, prefix: "unmnemonic_devices", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
    end
  end
end
