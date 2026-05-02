defmodule Registrations.Repo.Migrations.AddPuzzletLocation do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:puzzlets, prefix: "poles") do
      add(:latitude, :float)
      add(:longitude, :float)
      add(:accuracy_m, :float)
    end
  end
end
