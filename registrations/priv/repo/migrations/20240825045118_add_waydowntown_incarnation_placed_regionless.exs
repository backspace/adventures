defmodule Registrations.Repo.Migrations.AddWaydowntownIncarnationPlacedRegionless do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:incarnations, prefix: "waydowntown") do
      add(:placed, :boolean, null: false, default: true)
      modify(:region_id, :binary_id, null: true)
    end

    create(index(:incarnations, [:placed], prefix: "waydowntown"))
  end
end
