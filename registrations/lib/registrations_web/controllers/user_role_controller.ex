defmodule RegistrationsWeb.UserRoleController do
  use RegistrationsWeb, :controller

  import Ecto.Query, warn: false

  alias Registrations.Accounts
  alias Registrations.Repo

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, params) do
    user_roles = Accounts.list_all_user_roles(params)
    render(conn, "index.json", %{data: user_roles, conn: conn, params: params})
  end

  def users(conn, params) do
    users =
      RegistrationsWeb.User
      |> order_by(:email)
      |> Repo.all()

    render(conn, RegistrationsWeb.JSONAPI.UserView, "index.json", %{data: users, conn: conn, params: params})
  end

  def validators(conn, params) do
    current_user = Pow.Plug.current_user(conn)

    unless Accounts.has_role?(current_user, "validation_supervisor") or current_user.admin do
      conn
      |> put_status(:forbidden)
      |> json(%{errors: [%{detail: "Must be a validation supervisor or admin"}]})
    else
      validators = Accounts.list_users_with_role("validator")
      render(conn, RegistrationsWeb.JSONAPI.UserView, "index.json", %{data: validators, conn: conn, params: params})
    end
  end

  def create(conn, params) do
    current_user = Pow.Plug.current_user(conn)
    user_id = params["user_id"]
    role = params["role"]

    case Accounts.assign_role(user_id, role, current_user.id) do
      {:ok, user_role} ->
        conn
        |> put_status(:created)
        |> render("show.json", %{data: user_role, conn: conn, params: params})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    Accounts.remove_role(id)
    send_resp(conn, :no_content, "")
  end
end
