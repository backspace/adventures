defmodule Registrations.Repo.Migrations.CreateTeam do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:teams, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :text)
      add(:risk_aversion, :integer)
      add(:notes, :text)
      add(:user_ids, {:array, :uuid}, default: [])

      timestamps()
    end
  end
end
