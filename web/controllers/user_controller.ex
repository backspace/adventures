defmodule Cr2016site.UserController do
  use Cr2016site.Web, :controller

  alias Cr2016site.User

  plug Cr2016site.Plugs.Admin when action in [:index]
  plug Cr2016site.Plugs.LoginRequired when action in [:edit, :update]

  def index(conn, _params) do
    users = Repo.all(User)
    render conn, "index.html", users: users
  end

  def edit(conn, _) do
    users = Repo.all(User)
    current_user = conn.assigns[:current_user_object]
    changeset = User.details_changeset(current_user)

    render conn, "edit.html", user: current_user, relationships: Cr2016site.TeamFinder.relationships(current_user, users), changeset: changeset
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
        |> redirect(to: user_path(conn, :edit))
      {:error, changeset} ->
        render(conn, "edit.html", user: current_user, relationships: Cr2016site.TeamFinder.relationships(current_user, users), changeset: changeset)
    end
  end
end
