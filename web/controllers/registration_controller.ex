defmodule Cr2016site.RegistrationController do
  use Cr2016site.Web, :controller
  alias Cr2016site.User

  def new(conn, _params) do
    changeset = User.changeset(%User{})
    render conn, changeset: changeset
  end

  def create(conn, %{"user" => user_params}) do
    changeset = User.changeset(%User{}, user_params)

    case Cr2016site.Registration.create(changeset, Cr2016site.Repo) do
      {:ok, user} ->
        Cr2016site.Mailer.send_welcome_email(user.email)
        conn
        |> put_session(:current_user, user.id)
        |> put_flash(:info, "Your account was created")
        |> redirect(to: user_path(conn, :edit))
      {:error, changeset} ->
        conn
        |> put_flash(:error, "Unable to create account")
        |> render("new.html", changeset: changeset)
    end
  end
end
