defmodule RegistrationsWeb.UserController do
  use RegistrationsWeb, :controller

  alias RegistrationsWeb.User

  plug RegistrationsWeb.Plugs.Admin when action in [:index]
  plug RegistrationsWeb.Plugs.LoginRequired when action in [:edit, :update]

  def index(conn, _params) do
    users =
      from(u in User,
        order_by: [
          desc: u.team_id,
          asc:
            fragment(
              "CASE WHEN ? IS TRUE THEN 0 WHEN ? IS NULL THEN 1 ELSE 2 END",
              u.attending,
              u.attending
            )
        ]
      )
      |> Repo.all()
      |> Repo.preload(:team)

    render(conn, "index.html", users: users)
  end

  def edit(conn, _) do
    users = Repo.all(User)
    current_user_only = Repo.get_by(User, email: conn.assigns[:current_user].email)
    changeset = User.details_changeset(current_user_only)

    current_user = Repo.preload(current_user_only, team: [:users])

    conn =
      if Application.get_env(:registrations, :registration_closed) do
        put_flash(
          conn,
          :error,
          "You may change your details but it’s too late to guarantee the changes can be integrated"
        )
      else
        conn
      end

    render(conn, "edit.html",
      user: current_user,
      team: current_user.team,
      relationships: RegistrationsWeb.TeamFinder.relationships(current_user_only, users),
      changeset: changeset
    )
  end

  def delete_show(conn, _) do
    changeset = Pow.Plug.change_user(conn)

    conn
    |> put_flash(:info, "Log in to immediately delete your waydowntown account and all associated data")
    |> put_view(RegistrationsWeb.Pow.SessionView)
    |> render("new.html", %{action: Routes.user_path(conn, :delete), delete: true, changeset: changeset})
  end

  def delete(conn, _params) do
    case Pow.Plug.authenticate_user(conn, conn.params["user"]) do
      {:ok, conn} ->
        Pow.Plug.delete_user(conn)
        Pow.Plug.delete(conn)

        conn
        |> put_flash(:info, "Your account has been deleted. Sorry to see you go!")
        |> redirect(to: "/")

      {:error, conn} ->
        redirect(conn, to: "/delete")
    end
  end

  def update(conn, %{"user" => user_params}) do
    users = Repo.all(User)
    current_user = conn.assigns[:current_user]
    changeset = User.details_changeset(current_user, user_params)

    current_user = Repo.preload(current_user, team: [:users])

    case Repo.update(changeset) do
      {:ok, _} ->
        Registrations.Mailer.send_user_changes(current_user, changeset.changes)

        conn
        |> put_flash(:info, "Your details were saved")
        |> redirect(to: Routes.user_path(conn, :edit))

      {:error, changeset} ->
        render(conn, "edit.html",
          user: current_user,
          team: current_user.team,
          relationships: RegistrationsWeb.TeamFinder.relationships(current_user, users),
          changeset: changeset
        )
    end
  end

  def voicepass(conn, _params) do
    current_user = conn.assigns[:current_user]

    lines = User.voicepass_candidates()
    random_index = :rand.uniform(length(lines))
    new_voicepass = Enum.at(lines, random_index)

    changeset = User.voicepass_changeset(current_user, %{voicepass: new_voicepass})

    {:ok, new_user} = Repo.update(changeset)
    conn = sync_user(conn, new_user)

    json(conn, %{data: %{voicepass: new_voicepass}})
  end
end
