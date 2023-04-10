defmodule AdventureRegistrations.Repo.Migrations.CreateMessage do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:subject, :string)
      add(:content, :text)
      add(:ready, :boolean, default: false)
      add(:postmarked_at, :date)

      timestamps()
    end
  end
end
