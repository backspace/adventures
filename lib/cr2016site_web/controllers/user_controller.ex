defmodule Cr2016siteWeb.UserController do
  use Cr2016siteWeb, :controller

  alias Cr2016siteWeb.User

  plug Cr2016siteWeb.Plugs.Admin when action in [:index]
  plug Cr2016siteWeb.Plugs.LoginRequired when action in [:edit, :update]

  def index(conn, _params) do
    teams = Repo.all(Cr2016siteWeb.Team)

    users = Repo.all(User)
    |> Enum.map(fn(u) -> Map.put(u, :teamed, Enum.any?(teams, fn(t) -> Enum.member?(t.user_ids, u.id) end)) end)

    render conn, "index.html", users: users
  end

  def edit(conn, _) do
    users = Repo.all(User)
    current_user = conn.assigns[:current_user_object]
    changeset = User.details_changeset(current_user)

    conn = case Application.get_env(:cr2016site, :registration_closed) do
      true ->
        conn
        |> put_flash(:error, "You may change your details but it’s too late to guarantee the changes can be integrated")
      _ ->
        conn
    end

    render conn, "edit.html", user: current_user, relationships: Cr2016siteWeb.TeamFinder.relationships(current_user, users), changeset: changeset
  end

  def update(conn, %{"user" => user_params}) do
    users = Repo.all(User)
    current_user = conn.assigns[:current_user_object]
    changeset = User.details_changeset(current_user, user_params)

    case Repo.update(changeset) do
      {:ok, _} ->
        Cr2016site.Mailer.send_user_changes(current_user, changeset.changes)
        conn
        |> put_flash(:info, "Your details were saved")
        |> redirect(to: Routes.user_path(conn, :edit))
      {:error, changeset} ->
        render(conn, "edit.html", user: current_user, relationships: Cr2016siteWeb.TeamFinder.relationships(current_user, users), changeset: changeset)
    end
  end
end
