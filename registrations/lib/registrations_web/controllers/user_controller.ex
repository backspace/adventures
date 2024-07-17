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
      case Application.get_env(:registrations, :registration_closed) do
        true ->
          conn
          |> put_flash(
            :error,
            "You may change your details but it’s too late to guarantee the changes can be integrated"
          )

        _ ->
          conn
      end

    render(conn, "edit.html",
      user: current_user,
      team: current_user.team,
      relationships: RegistrationsWeb.TeamFinder.relationships(current_user_only, users),
      changeset: changeset
    )
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

    Repo.update(changeset)

    json(conn, %{data: %{voicepass: new_voicepass}})
  end
end
