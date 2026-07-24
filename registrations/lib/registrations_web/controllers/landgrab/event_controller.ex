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
      endgame: render_endgame(event),
      # Newest app build the server has seen ping in, per platform. The client
      # compares its own build against its platform's value and shows a soft
      # "update available" banner when it's behind. Null until a build pings.
      latest_build_ios: event.latest_build_ios,
      latest_build_android: event.latest_build_android
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
