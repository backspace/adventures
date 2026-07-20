defmodule RegistrationsWeb.Landgrab.PoleController do
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab
  alias Registrations.Landgrab.PlayerStrings
  alias RegistrationsWeb.Landgrab.Render

  # Scanning a stake is a gameplay action — refused until the event starts.
  plug(RegistrationsWeb.Plugs.RequireEventStarted when action in [:show])

  def index(conn, _params) do
    # Pass the viewer's team so poles prohibitive for that team (every remaining
    # puzzlet conflicts with a member's accessibility needs) come back flagged.
    user = Pow.Plug.current_user(conn)
    states = Landgrab.list_poles_with_state(user && user.team_id)
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
            detail: PlayerStrings.at_capacity_detail()
          },
          pole: Render.pole_state(Landgrab.pole_with_state(pole)),
          active_puzzlets: Enum.map(active, &Render.scan_payload/1)
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "pole_not_found", detail: PlayerStrings.stake_not_found_detail()}})

      {:error, :already_owner, pole} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "already_owner",
            detail: PlayerStrings.already_owner_detail()
          },
          pole: Render.pole_state(Landgrab.pole_with_state(pole))
        })

      {:error, :own_creation, pole} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "own_creation",
            detail: PlayerStrings.own_creation_detail()
          },
          pole: Render.pole_state(Landgrab.pole_with_state(pole))
        })

      {:error, :outside_zone, pole} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "outside_zone",
            detail: PlayerStrings.outside_zone_detail()
          },
          pole: Render.pole_state(Landgrab.pole_with_state(pole))
        })

      {:error, :team_locked_out, pole} ->
        conn
        |> put_status(:locked)
        |> json(%{
          error: %{
            code: "team_locked_out",
            detail: PlayerStrings.team_locked_out_detail()
          },
          pole: Render.pole_state(Landgrab.pole_with_state(pole))
        })
    end
  end
end
