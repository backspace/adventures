defmodule AdventureRegistrationsWeb.UserController do
  use AdventureRegistrationsWeb, :controller

  alias AdventureRegistrationsWeb.User

  plug AdventureRegistrationsWeb.Plugs.Admin when action in [:index]
  plug AdventureRegistrationsWeb.Plugs.LoginRequired when action in [:edit, :update]

  def index(conn, _params) do
    teams = Repo.all(AdventureRegistrationsWeb.Team)

    users = Repo.all(User)
    |> Enum.map(fn(u) -> Map.put(u, :teamed, Enum.any?(teams, fn(t) -> Enum.member?(t.user_ids, u.id) end)) end)

    render conn, "index.html", users: users
  end

  def edit(conn, _) do
    users = Repo.all(User)
    current_user = conn.assigns[:current_user_object]
    changeset = User.details_changeset(current_user)

    conn = case Application.get_env(:adventure_registrations, :registration_closed) do
      true ->
        conn
        |> put_flash(:error, "You may change your details but it’s too late to guarantee the changes can be integrated")
      _ ->
        conn
    end

    render conn, "edit.html", user: current_user, relationships: AdventureRegistrationsWeb.TeamFinder.relationships(current_user, users), changeset: changeset
  end

  def update(conn, %{"user" => user_params}) do
    users = Repo.all(User)
    current_user = conn.assigns[:current_user_object]
    changeset = User.details_changeset(current_user, user_params)

    case Repo.update(changeset) do
      {:ok, _} ->
        AdventureRegistrations.Mailer.send_user_changes(current_user, changeset.changes)
        conn
        |> put_flash(:info, "Your details were saved")
        |> redirect(to: Routes.user_path(conn, :edit))
      {:error, changeset} ->
        render(conn, "edit.html", user: current_user, relationships: AdventureRegistrationsWeb.TeamFinder.relationships(current_user, users), changeset: changeset)
    end
  end
end
