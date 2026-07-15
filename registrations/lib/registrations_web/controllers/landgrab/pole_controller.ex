defmodule RegistrationsWeb.Landgrab.PoleController do
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab
  alias RegistrationsWeb.Landgrab.Render

  def index(conn, _params) do
    states = Landgrab.list_poles_with_state()
    json(conn, %{poles: Enum.map(states, &Render.pole_state/1)})
  end

  def show(conn, %{"barcode" => barcode}) do
    user = Pow.Plug.current_user(conn)

    case Landgrab.scan_payload(barcode, user.team_id, user.id) do
      {:ok, state} ->
        json(conn, Render.scan_payload(state))

      {:error, :at_capacity, active, pole} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "at_capacity",
            detail:
              "Your team is already working on a puzzlet. Finish it or give it up before " <>
                "starting another."
          },
          pole: Render.pole_state(Landgrab.pole_with_state(pole)),
          active_puzzlets: Enum.map(active, &Render.scan_payload/1)
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
          pole: Render.pole_state(Landgrab.pole_with_state(pole))
        })

      {:error, :own_creation, pole} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "own_creation",
            detail: "You created this pole — you can't capture it."
          },
          pole: Render.pole_state(Landgrab.pole_with_state(pole))
        })

      {:error, :outside_zone, pole} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "outside_zone",
            detail: Registrations.Landgrab.PlayerStrings.outside_zone_detail()
          },
          pole: Render.pole_state(Landgrab.pole_with_state(pole))
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
          pole: Render.pole_state(Landgrab.pole_with_state(pole))
        })
    end
  end
end
