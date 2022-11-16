defmodule AdventureRegistrations.Repo.Migrations.AddMessageTeamBoolean do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add(:show_team, :boolean)
    end
  end
end
