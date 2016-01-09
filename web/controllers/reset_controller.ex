defmodule Cr2016site.ResetController do
  use Cr2016site.Web, :controller
  alias Cr2016site.User
  alias Cr2016site.Repo

  def new(conn, _params) do
    changeset = User.reset_changeset(%User{})
    render conn, changeset: changeset
  end

  def create(conn, %{"user" => user_params}) do
    user = Repo.get_by(Cr2016site.User, email: user_params["email"])

    case Cr2016site.Reset.create(user, Repo) do
      {:ok, user} ->
        Cr2016site.Mailer.send_password_reset(user)
      {:error, _} ->
        # nothing
    end

    conn
    |> put_flash(:info, "Check your email for a password reset link")
    |> redirect(to: page_path(conn, :index))
  end

  def edit(conn, %{"token" => token}) do
    case Repo.get_by(Cr2016site.User, recovery_hash: token) do
      nil ->
        conn
        |> put_flash(:error, "Unknown password reset token")
        |> redirect(to: page_path(conn, :index))
      user ->
        changeset = User.perform_reset_changeset(user, %{"recovery_hash" => token})
        render conn, changeset: changeset, token: token
    end
  end

  def update(conn, %{"user" => user_params}) do
    user = Repo.get_by(Cr2016site.User, recovery_hash: user_params["recovery_hash"]) || %User{}
    changeset = User.perform_reset_changeset(user, user_params)

    case Cr2016site.Reset.update(changeset, Repo) do
      {:ok, user} ->
        conn
        |> put_session(:current_user, user.id)
        |> put_flash(:info, "Your password has been changed")
        |> redirect(to: user_path(conn, :edit))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "New passwords must match")
        |> render "edit.html", changeset: changeset, token: user_params["recovery_hash"]
    end
  end
end
