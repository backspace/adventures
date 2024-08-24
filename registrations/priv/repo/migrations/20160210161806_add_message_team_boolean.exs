defmodule Registrations.Repo.Migrations.AddMessageTeamBoolean do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add(:show_team, :boolean)
    end
  end
end
