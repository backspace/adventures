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

  # Bedab's final-location messages — a separate action from the boundary
  # `update` (which is deliberately full-replace over its six fields) so a
  # message edit can never clear the boundary or vice versa. Editable until
  # the announcer sends them (once the shrink begins); edits after sending
  # save fine but reach no one — the sent stamp in the payload says so.
  def update_messages(conn, params) do
    attrs = %{
      final_message_joined: params["joined"],
      final_message_others: params["others"]
    }

    case Events.update(Events.current(), attrs) do
      {:ok, updated} ->
        json(conn, render_endgame(updated))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)})
    end
  end

  # Push every scheduled endgame + liberation milestone back five minutes,
  # preserving their spacing — a live "we're running behind" control. Leaves
  # the event's start_time and the one-shot stamps alone. Broadcasts so player
  # maps and countdowns re-sync immediately.
  @shift_seconds 5 * 60

  def shift(conn, _params) do
    case Events.shift_schedule(Events.current(), @shift_seconds) do
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

    %{
      endgame: endgame,
      announced_at: event.endgame_announced_at,
      final_messages: %{
        joined: event.final_message_joined,
        others: event.final_message_others,
        sent_at: event.final_messages_sent_at
      }
    }
  end
end
