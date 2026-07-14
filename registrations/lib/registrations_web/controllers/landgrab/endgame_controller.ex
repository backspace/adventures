defmodule RegistrationsWeb.Landgrab.EndgameController do
  @moduledoc """
  Supervisor-editable endgame boundary. Lives in the app (map-based
  centre/radius picking) rather than the admin site because the
  centre may need to move on the day as conditions change. PUT is
  full-replace: send all six fields to (re)configure, or all nulls to
  clear. Saving broadcasts `event_updated` so every connected player
  map re-syncs the boundary immediately.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Events

  def show(conn, _params) do
    json(conn, render_endgame(Events.current()))
  end

  def update(conn, params) do
    event = Events.current()

    attrs = %{
      endgame_latitude: params["latitude"],
      endgame_longitude: params["longitude"],
      endgame_starts_at: params["starts_at"],
      endgame_ends_at: params["ends_at"],
      endgame_initial_radius_m: params["initial_radius_m"],
      endgame_final_radius_m: params["final_radius_m"]
    }

    case Events.update(event, attrs) do
      {:ok, updated} ->
        RegistrationsWeb.Endpoint.broadcast("landgrab:map", "event_updated", %{})
        json(conn, render_endgame(updated))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)})
    end
  end

  defp render_endgame(event) do
    endgame =
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

    %{endgame: endgame, announced_at: event.endgame_announced_at}
  end
end
