defmodule RegistrationsWeb.Landgrab.MeController do
  use RegistrationsWeb, :controller

  alias Registrations.Accounts
  alias Registrations.Repo

  def show(conn, _params) do
    user = conn |> Pow.Plug.current_user() |> Repo.preload(:team)
    roles = user |> Accounts.list_user_roles() |> Enum.map(& &1.role)

    json(conn, %{
      user: %{id: user.id, email: user.email, name: user.name, roles: roles},
      team: render_team(user.team)
    })
  end

  defp render_team(nil), do: nil

  defp render_team(team) do
    # The team's stable colour index (its rank among joined teams), so the app
    # can show the team's map colour beside its name from launch — before it
    # owns any zone. Independent of captures; only shifts as teams join.
    color_index =
      Registrations.Landgrab.team_style_index()
      |> Map.get(team.id, %{})
      |> Map.get(:color_index)

    %{id: team.id, name: team.name, color_index: color_index}
  end
end
