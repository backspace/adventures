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
      {:ok, changeset} ->
        conn
        |> redirect(to: "/")
    end
  end
end
