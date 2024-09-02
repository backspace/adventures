defmodule Registrations.Repo.Migrations.AddGeomToWaydowntownRegions do
  @moduledoc false
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS postgis")

    alter table(:regions, prefix: "waydowntown") do
      add(:geom, :geometry)
    end

    execute("""
    UPDATE waydowntown.regions
    SET geom = ST_SetSRID(ST_MakePoint(longitude::float, latitude::float), 4326)
    """)

    execute("CREATE INDEX regions_geom_idx ON waydowntown.regions USING GIST (geom)")

    alter table(:regions, prefix: "waydowntown") do
      remove(:latitude)
      remove(:longitude)
    end
  end

  def down do
    alter table(:regions, prefix: "waydowntown") do
      add(:latitude, :float)
      add(:longitude, :float)
    end

    execute("""
    UPDATE waydowntown.regions
    SET latitude = ST_Y(geom), longitude = ST_X(geom)
    """)

    alter table(:regions, prefix: "waydowntown") do
      remove(:geom)
    end

    execute("DROP INDEX IF EXISTS regions_geom_idx")
    execute("DROP EXTENSION IF EXISTS postgis")
  end
end
