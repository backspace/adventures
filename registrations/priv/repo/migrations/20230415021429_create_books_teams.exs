defmodule AdventureRegistrations.Repo.Migrations.CreateBooksTeams do
  use Ecto.Migration

  def change do
    create table(:books_teams, prefix: "unmnemonic_devices", primary_key: false) do
      add(:book_id, references("books", type: :uuid), primary_key: true, null: false)

      add(:team_id, references("teams", prefix: "public", type: :uuid),
        primary_key: true,
        null: false
      )
    end
  end
end
