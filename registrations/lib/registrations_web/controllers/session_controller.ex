defmodule RegistrationsWeb.SessionController do
  use RegistrationsWeb, :controller

  def new(conn, _params) do
    render(conn, "new.html")
  end

  # FIXME can this be tested? It uses HTTPOnly cookie
  def show(conn, params) do
    render(conn, "show.json", %{conn: conn, params: params})
  end

  def create(conn, %{"session" => session_params}) do
    case RegistrationsWeb.Session.login(session_params, Registrations.Repo) do
      {:ok, user} ->
        conn
        |> put_session(:current_user, user.id)
        |> put_flash(:info, "Logged in")
        |> redirect(to: Routes.user_path(conn, :edit))

      :error ->
        conn
        |> put_flash(:error, "Wrong email or password")
        |> render("new.html")
    end
  end

  def delete(conn, _) do
    conn
    |> delete_session(:current_user)
    |> put_flash(:info, "Logged out")
    |> redirect(to: "/")
  end
end
