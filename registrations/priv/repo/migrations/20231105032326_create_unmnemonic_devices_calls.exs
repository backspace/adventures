defmodule AdventureRegistrations.Repo.Migrations.CreateUnmnemonicDevicesCalls do
  use Ecto.Migration

  def change do
    create table(:calls, prefix: "unmnemonic_devices", primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:number, :string)
      add(:team_id, references("teams", prefix: "public", type: :uuid))
      add(:created_at, :utc_datetime, default: fragment("now()"))
    end
  end
end
