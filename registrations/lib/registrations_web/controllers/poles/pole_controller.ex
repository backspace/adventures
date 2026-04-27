defmodule RegistrationsWeb.Poles.PoleController do
  use RegistrationsWeb, :controller

  alias Registrations.Poles

  def index(conn, _params) do
    states = Poles.list_poles_with_state()
    json(conn, %{poles: Enum.map(states, &render_pole_state/1)})
  end

  def show(conn, %{"barcode" => barcode}) do
    user = Pow.Plug.current_user(conn)

    case Poles.scan_payload(barcode, user.team_id) do
      {:ok, state} ->
        json(conn, %{
          pole: render_pole_state(state),
          active_puzzlet: render_puzzlet(state.active_puzzlet, state.attempts_remaining)
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "pole_not_found", detail: "No pole with that barcode."}})
    end
  end

  defp render_pole_state(%{pole: pole, current_owner_team_id: owner, locked?: locked}) do
    %{
      id: pole.id,
      barcode: pole.barcode,
      label: pole.label,
      latitude: pole.latitude,
      longitude: pole.longitude,
      current_owner_team_id: owner,
      locked: locked
    }
  end

  defp render_puzzlet(nil, _), do: nil

  defp render_puzzlet(puzzlet, attempts_remaining) do
    %{
      id: puzzlet.id,
      instructions: puzzlet.instructions,
      difficulty: puzzlet.difficulty,
      attempts_remaining: attempts_remaining
    }
  end
end
