defmodule RegistrationsWeb.Landgrab.TeamController do
  @moduledoc """
  Player-facing team actions for the mobile app. Currently just
  join-by-code: teammates scan a team card's QR (or type its code) to
  land on the same team, instead of the pre-event email-matching flow.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Repo
  alias RegistrationsWeb.Team

  def join(conn, %{"code" => code}) do
    normalized = code |> to_string() |> String.trim() |> String.upcase()

    case normalized != "" && Repo.get_by(Team, join_code: normalized) do
      %Team{} = team ->
        user = Pow.Plug.current_user(conn)

        {:ok, _updated} =
          user
          |> Ecto.Changeset.change(team_id: team.id)
          |> Repo.update()

        json(conn, %{team: %{id: team.id, name: team.name}})

      _ ->
        conn
        |> put_status(404)
        |> json(%{error: %{status: 404, detail: "No team with that code."}})
    end
  end
end
