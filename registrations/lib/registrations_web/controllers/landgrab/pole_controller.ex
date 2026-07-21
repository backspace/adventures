defmodule RegistrationsWeb.Landgrab.PoleController do
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab
  alias Registrations.Landgrab.PlayerStrings
  alias RegistrationsWeb.Landgrab.Render

  # Scanning / claiming a stake are gameplay actions — refused until the event
  # starts.
  plug(RegistrationsWeb.Plugs.RequireEventStarted when action in [:show, :accommodate])

  def index(conn, _params) do
    # Pass the viewer's team so poles prohibitive for that team (every remaining
    # puzzlet conflicts with a member's accessibility needs) come back flagged.
    user = Pow.Plug.current_user(conn)
    states = Landgrab.list_poles_with_state(user && user.team_id)
    json(conn, %{poles: Enum.map(states, &Render.pole_state/1)})
  end

  def show(conn, %{"barcode" => barcode} = params) do
    user = Pow.Plug.current_user(conn)
    # Puzzlets the team declined this scan session ("Not this one" on an
    # accessibility conflict) — skip them when choosing what to serve.
    exclude = parse_exclude(params["exclude"])

    case Landgrab.scan_payload(barcode, user.team_id, user.id, exclude) do
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

      # Strict roles: a liberator scanning unowned (or already-liberated)
      # ground has nothing to free here.
      {:error, :nothing_to_liberate, pole} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "nothing_to_liberate",
            detail: PlayerStrings.nothing_to_liberate_detail()
          },
          pole: Render.pole_state(Landgrab.pole_with_state(pole))
        })
    end
  end

  # Claim a prohibitive stake without solving (accommodation). Presence is the
  # gate as with scanning: the stake is resolved by its scanned barcode.
  def accommodate(conn, %{"barcode" => barcode}) do
    user = Pow.Plug.current_user(conn)

    case Landgrab.get_pole_by_barcode(barcode) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "pole_not_found", detail: PlayerStrings.stake_not_found_detail()}})

      pole ->
        case Landgrab.accommodate_pole(pole, user.team_id, user.id) do
          {:ok, claimed} ->
            json(conn, %{pole: Render.pole_state(Landgrab.pole_with_state(claimed))})

          {:error, :no_team} ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: %{code: "no_team", detail: PlayerStrings.no_team_detail()}})

          {:error, :already_owner} ->
            claim_error(conn, pole, "already_owner", PlayerStrings.already_owner_detail())

          {:error, :outside_zone} ->
            claim_error(conn, pole, "outside_zone", PlayerStrings.outside_zone_detail())

          {:error, :not_prohibitive} ->
            claim_error(conn, pole, "not_prohibitive", PlayerStrings.not_prohibitive_detail())

          {:error, :nothing_to_liberate} ->
            claim_error(conn, pole, "nothing_to_liberate", PlayerStrings.nothing_to_liberate_detail())

          {:error, _} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: %{code: "claim_failed", detail: PlayerStrings.claim_failed_detail()}})
        end
    end
  end

  defp claim_error(conn, pole, code, detail) do
    conn
    |> put_status(:conflict)
    |> json(%{
      error: %{code: code, detail: detail},
      pole: Render.pole_state(Landgrab.pole_with_state(pole))
    })
  end

  # Comma-separated declined puzzlet ids from the `exclude` query param.
  defp parse_exclude(nil), do: []
  defp parse_exclude(""), do: []

  defp parse_exclude(csv) when is_binary(csv),
    do: csv |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

  defp parse_exclude(_), do: []
end
