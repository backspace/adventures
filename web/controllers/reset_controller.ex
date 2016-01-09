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
      {:ok, _} ->
        Cr2016site.Mailer.send_password_reset(user)
      {:error, _} ->
        # nothing
    end

    conn
    |> put_flash(:info, "Check your email for a password reset link")
    |> redirect(to: page_path(conn, :index))
  end
end
