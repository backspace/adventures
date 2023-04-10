defmodule AdventureRegistrationsWeb.ResetController do
  use AdventureRegistrationsWeb, :controller
  alias AdventureRegistrationsWeb.User
  alias AdventureRegistrations.Repo

  def new(conn, _params) do
    changeset = User.reset_changeset(%User{})
    render conn, changeset: changeset
  end

  def create(conn, %{"user" => user_params}) do
    user = Repo.get_by(AdventureRegistrationsWeb.User, email: user_params["email"])

    case AdventureRegistrationsWeb.Reset.create(user, Repo) do
      {:ok, user} ->
        AdventureRegistrations.Mailer.send_password_reset(user)
        conn
        |> put_flash(:info, "Check your email for a password reset link")
        |> redirect(to: Routes.page_path(conn, :index))
      {:error, _} ->
        conn
        |> put_flash(:error, "No registration with that email address found")
        |> render("new.html", changeset: User.reset_changeset(%User{}))
    end
  end

  def edit(conn, %{"token" => token}) do
    case Repo.get_by(AdventureRegistrationsWeb.User, recovery_hash: token) do
      nil ->
        conn
        |> put_flash(:error, "Unknown password reset token")
        |> redirect(to: Routes.page_path(conn, :index))
      user ->
        changeset = User.perform_reset_changeset(user, %{"recovery_hash" => token})
        render conn, changeset: changeset, token: token
    end
  end

  def update(conn, %{"user" => user_params}) do
    user = Repo.get_by(AdventureRegistrationsWeb.User, recovery_hash: user_params["recovery_hash"]) || %User{}
    changeset = User.perform_reset_changeset(user, user_params)

    case AdventureRegistrationsWeb.Reset.update(changeset, Repo) do
      {:ok, user} ->
        conn
        |> put_session(:current_user, user.id)
        |> put_flash(:info, "Your password has been changed")
        |> redirect(to: Routes.user_path(conn, :edit))
      {:error, changeset} ->
        # TODO this is a hack to ensure the token is present in the hidden field when an attempt fails, but why isn’t it already?
        changeset = Ecto.Changeset.put_change(changeset, :recovery_hash, user_params["recovery_hash"])

        conn
        |> put_flash(:error, "New passwords must match")
        |> render("edit.html", changeset: changeset, token: user_params["recovery_hash"])
    end
  end
end
