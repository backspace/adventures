defmodule Cr2016site.Repo.Migrations.CreateTeam do
  use Ecto.Migration

  def change do
    create table(:teams, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :risk_aversion, :integer
      add :notes, :text
      add :user_ids, {:array, :binary_id}

      timestamps
    end

  end
end
