defmodule RegistrationsWeb.Landgrab.EventController do
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Events

  def show(conn, _params) do
    event = Events.current()
    now = DateTime.utc_now()

    json(conn, %{
      name: event.name,
      start_time: event.start_time,
      started: Event.started?(event, now),
      endgame: render_endgame(event)
    })
  end

  # The client re-derives the current radius from these with the same
  # linear interpolation the server enforces, so the map circle can
  # shrink smoothly without polling.
  defp render_endgame(event) do
    if Event.endgame_configured?(event) do
      %{
        latitude: event.endgame_latitude,
        longitude: event.endgame_longitude,
        starts_at: event.endgame_starts_at,
        ends_at: event.endgame_ends_at,
        initial_radius_m: event.endgame_initial_radius_m,
        final_radius_m: event.endgame_final_radius_m
      }
    end
  end
end
