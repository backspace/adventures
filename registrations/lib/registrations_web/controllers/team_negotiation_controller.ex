defmodule RegistrationsWeb.TeamNegotiationController do
  use RegistrationsWeb, :controller

  alias Registrations.Repo
  alias RegistrationsWeb.TeamFinder
  alias RegistrationsWeb.User
  alias RegistrationsWeb.JSONAPI.TeamNegotiationView

  action_fallback(RegistrationsWeb.FallbackController)

  def show(conn, _params) do
    current_user = Pow.Plug.current_user(conn)
    users = Repo.all(User)
    current_user_with_team = Repo.preload(current_user, team: [:users])
    relationships = TeamFinder.relationships(current_user, users)

    conn
    |> put_view(TeamNegotiationView)
    |> render("show.json",
      data: current_user_with_team,
      relationships: relationships,
      conn: conn
    )
  end
end
