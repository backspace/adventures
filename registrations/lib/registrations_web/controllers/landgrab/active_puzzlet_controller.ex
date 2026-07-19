defmodule RegistrationsWeb.Landgrab.ActivePuzzletController do
  @moduledoc """
  The team's active puzzlet(s) — the puzzlet a member scanned that the
  whole team is now working on. `index` lets any member resume without
  rescanning; `create` assigns the next puzzlet for a pole without a
  rescan (the "try the next one" offer after a rival captures yours);
  `delete` gives one up.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab
  alias RegistrationsWeb.Landgrab.Render

  def index(conn, _params) do
    user = Pow.Plug.current_user(conn)

    payloads =
      if user.team_id do
        user.team_id |> Landgrab.list_active_puzzlets_for_team() |> Enum.map(&Render.scan_payload/1)
      else
        []
      end

    json(conn, %{active_puzzlets: payloads})
  end

  def create(conn, %{"pole_id" => pole_id}) do
    user = Pow.Plug.current_user(conn)

    if is_nil(user.team_id) do
      forbidden_no_team(conn)
    else
      case Landgrab.assign_active_puzzlet_for_pole(user.team_id, user.id, pole_id) do
        {:ok, _puzzlet} ->
          # Re-read as the full payload the app renders/resumes into.
          payload =
            user.team_id
            |> Landgrab.list_active_puzzlets_for_team()
            |> Enum.find(fn p -> p.pole.id == pole_id end)

          conn |> put_status(:created) |> json(Render.scan_payload(payload))

        {:already_active, _puzzlet} ->
          payload =
            user.team_id
            |> Landgrab.list_active_puzzlets_for_team()
            |> Enum.find(fn p -> p.pole.id == pole_id end)

          json(conn, Render.scan_payload(payload))

        {:error, :at_capacity} ->
          error(conn, :conflict, "at_capacity", Landgrab.PlayerStrings.at_capacity_detail())

        {:error, :team_locked_out} ->
          error(conn, :locked, "team_locked_out", Landgrab.PlayerStrings.team_locked_out_detail())

        {:error, :no_puzzlet} ->
          error(conn, :not_found, "no_puzzlet", Landgrab.PlayerStrings.no_relic_detail())

        {:error, :not_found} ->
          error(conn, :not_found, "pole_not_found", Landgrab.PlayerStrings.stake_not_found_detail())
      end
    end
  end

  def delete(conn, %{"puzzlet_id" => puzzlet_id}) do
    user = Pow.Plug.current_user(conn)
    if user.team_id, do: Landgrab.abandon_active_puzzlet(user.team_id, puzzlet_id)
    json(conn, %{ok: true})
  end

  defp forbidden_no_team(conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: %{code: "no_team", detail: Landgrab.PlayerStrings.no_team_detail()}})
  end

  defp error(conn, status, code, detail) do
    conn |> put_status(status) |> json(%{error: %{code: code, detail: detail}})
  end
end
