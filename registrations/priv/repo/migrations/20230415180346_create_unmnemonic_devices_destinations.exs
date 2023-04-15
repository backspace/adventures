defmodule AdventureRegistrations.Repo.Migrations.CreateUnmnemonicDevicesDestinations do
  use Ecto.Migration

  def change do
    create table(:destinations, prefix: "unmnemonic_devices", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:description, :string)
      add(:region_id, references("regions", type: :uuid), null: false)
    end
  end
end
