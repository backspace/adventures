defmodule AdventureRegistrations.Repo.Migrations.CreateBooks do
  use Ecto.Migration

  def change do
    create table(:books, prefix: "unmnemonic_devices", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:excerpt, :string)
      add(:title, :string)
    end
  end
end
