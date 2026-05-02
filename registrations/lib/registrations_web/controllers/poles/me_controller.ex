defmodule RegistrationsWeb.Poles.MeController do
  use RegistrationsWeb, :controller

  alias Registrations.Repo

  def show(conn, _params) do
    user = conn |> Pow.Plug.current_user() |> Repo.preload(:team)

    json(conn, %{
      user: %{id: user.id, email: user.email, name: user.name},
      team: render_team(user.team)
    })
  end

  defp render_team(nil), do: nil
  defp render_team(team), do: %{id: team.id, name: team.name}
end
