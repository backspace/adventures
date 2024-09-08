defmodule Registrations.Repo.Migrations.AddWaydowntownGameStartTimeAndIncarnationDuration do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:incarnations, prefix: "waydowntown") do
      add(:duration_seconds, :integer, null: true)
    end

    alter table(:games, prefix: "waydowntown") do
      add(:started_at, :utc_datetime_usec, null: true)
    end
  end
end
