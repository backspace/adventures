defmodule AdventureRegistrations.Repo.Migrations.CreateUnmnemonicDevicesMeetings do
  use Ecto.Migration

  def change do
    create table(:meetings, prefix: "unmnemonic_devices", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:book_id, references("books", type: :uuid), null: false)
      add(:destination_id, references("destinations", type: :uuid), null: false)

      add(:team_id, references("teams", prefix: "public", type: :uuid), null: false)
    end
  end
end
