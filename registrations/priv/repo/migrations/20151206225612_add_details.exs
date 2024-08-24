defmodule Registrations.Repo.Migrations.AddDetails do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:proposed_team_name, :text)
      add(:risk_aversion, :integer)
    end
  end
end
