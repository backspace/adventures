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
          active_puzzlet:
            render_puzzlet(
              state.active_puzzlet,
              state.attempts_remaining,
              state.previous_wrong_answers
            )
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "pole_not_found", detail: "No pole with that barcode."}})

      {:error, :already_owner, pole} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "already_owner",
            detail: "Your team already owns this pole. Wait for a rival to capture it."
          },
          pole: render_pole_state(Poles.pole_with_state(pole))
        })

      {:error, :team_locked_out, pole} ->
        conn
        |> put_status(:locked)
        |> json(%{
          error: %{
            code: "team_locked_out",
            detail:
              "Your team has used all guesses on the current puzzlet for this pole. " <>
                "Wait for another team to capture it before you can try again."
          },
          pole: render_pole_state(Poles.pole_with_state(pole))
        })
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

  defp render_puzzlet(nil, _, _), do: nil

  defp render_puzzlet(puzzlet, attempts_remaining, previous_wrong_answers) do
    %{
      id: puzzlet.id,
      instructions: puzzlet.instructions,
      difficulty: puzzlet.difficulty,
      attempts_remaining: attempts_remaining,
      previous_wrong_answers: previous_wrong_answers
    }
  end
end
