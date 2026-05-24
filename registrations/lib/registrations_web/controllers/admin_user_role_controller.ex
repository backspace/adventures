defmodule RegistrationsWeb.AdminUserRoleController do
  use RegistrationsWeb, :controller

  import Ecto.Query

  alias Registrations.Accounts
  alias Registrations.Repo

  plug RegistrationsWeb.Plugs.Admin

  @roles ~w(author validator validation_supervisor)

  def index(conn, _params) do
    users =
      RegistrationsWeb.User
      |> order_by(:email)
      |> Repo.all()

    user_roles = Accounts.list_all_user_roles()
    roles_by_user = Enum.group_by(user_roles, & &1.user_id)

    render(conn, "index.html",
      users: users,
      roles_by_user: roles_by_user,
      role_choices: @roles
    )
  end

  def create(conn, %{"user_id" => user_id, "role" => role}) when role in @roles do
    current_user = Pow.Plug.current_user(conn)

    case Accounts.assign_role(user_id, role, current_user.id) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Role assigned.")
        |> redirect(to: Routes.admin_user_role_path(conn, :index))

      {:error, %Ecto.Changeset{errors: errors}} ->
        detail =
          if Keyword.has_key?(errors, :user_id_role) or
               Enum.any?(errors, fn {_, {msg, _}} ->
                 String.contains?(msg, "already") or String.contains?(msg, "taken")
               end) do
            "User already has that role."
          else
            "Could not assign role."
          end

        conn
        |> put_flash(:error, detail)
        |> redirect(to: Routes.admin_user_role_path(conn, :index))
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid role.")
    |> redirect(to: Routes.admin_user_role_path(conn, :index))
  end

  def delete(conn, %{"id" => id}) do
    Accounts.remove_role(id)

    conn
    |> put_flash(:info, "Role removed.")
    |> redirect(to: Routes.admin_user_role_path(conn, :index))
  end
end
