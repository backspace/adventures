defmodule Registrations.Repo.Migrations.AddEventEndgame do
  use Ecto.Migration

  def change do
    # The endgame zone: a capture boundary that shrinks linearly from
    # initial_radius to final_radius (centred on the wrap-party spot)
    # between starts_at and ends_at. Current radius is derived from
    # the clock by both server and client — no ticking state.
    # announced_at records the one-shot SYSTEM broadcast.
    alter table("events", prefix: "landgrab") do
      add(:endgame_latitude, :float)
      add(:endgame_longitude, :float)
      add(:endgame_starts_at, :utc_datetime)
      add(:endgame_ends_at, :utc_datetime)
      add(:endgame_initial_radius_m, :float)
      add(:endgame_final_radius_m, :float)
      add(:endgame_announced_at, :utc_datetime)
    end
  end
end
