defmodule Cr2016site.ResetController do
  use Cr2016site.Web, :controller
  alias Cr2016site.User

  def new(conn, _params) do
    changeset = User.reset_changeset(%User{})
    render conn, changeset: changeset
  end

  def create(conn, %{"user" => user_params}) do
    changeset = User.reset_changeset(%User{}, user_params)

    user = Cr2016site.Repo.get_by(User, email: changeset.changes.email)

    if user do
      Cr2016site.Mailer.send_password_reset(user)
    end

    conn
    |> put_flash(:info, "Check your email for a password reset link")
    |> redirect(to: page_path(conn, :index))
  end
end
