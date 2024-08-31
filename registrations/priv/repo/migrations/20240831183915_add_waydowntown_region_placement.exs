defmodule Registrations.Repo.Migrations.AddWaydowntownRegionPlacement do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:regions, prefix: "waydowntown") do
      add(:latitude, :decimal)
      add(:longitude, :decimal)
    end
  end
end
