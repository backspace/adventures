defmodule RegistrationsWeb.Landgrab.ReliefController do
  @moduledoc """
  Supervisor toggle for the relief valve — re-opens stakes for per-team
  consumption when the event runs ahead of content (teams have solved most of
  what's out there). A live switch, not a schedule: `on: true` stamps
  `relief_started_at`, `on: false` clears it. Broadcasts `event_updated` so
  player maps re-fetch (a stake drained only by *others* becomes playable
  again, and its lock lifts per-team).
  """
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Events

  def show(conn, _params) do
    stats = Landgrab.relief_stats()

    json(conn, %{
      active: active?(),
      total_poles: stats.total_poles,
      in_play: stats.in_play,
      not_fully_captured: stats.not_fully_captured,
      capturable_in_play: stats.capturable_in_play,
      leaderboard:
        Enum.map(stats.leaderboard, fn e ->
          %{team_id: e.team_id, name: e.name, owned: e.owned}
        end)
    })
  end

  def update(conn, params) do
    event = Events.current()
    on = params["on"] == true

    stamp =
      if on, do: DateTime.utc_now() |> DateTime.truncate(:second), else: nil

    case Events.update(event, %{relief_started_at: stamp}) do
      {:ok, _updated} ->
        RegistrationsWeb.Endpoint.broadcast("landgrab:map", "event_updated", %{})
        json(conn, %{active: on})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)})
    end
  end

  defp active? do
    match?(%{relief_started_at: %DateTime{}}, Events.current())
  end
end
