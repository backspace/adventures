defmodule AdventureRegistrations.Repo.Migrations.AddSettingsTable do
  use Ecto.Migration

  def change do
    create table("settings") do
      add :override, :text
      add :begun, :boolean, default: false
      add :ending, :boolean, default: false
      add :down, :boolean, default: false

      timestamps()
    end
  end
end
