defmodule RegistrationsWeb.SessionView do
  use JSONAPI.View, type: "session"

  alias RegistrationsWeb.SessionView

  def fields do
    [:admin, :email, :name, :roles]
  end

  def roles(user, _conn) do
    if Ecto.assoc_loaded?(user.user_roles) do
      Enum.map(user.user_roles, & &1.role)
    else
      []
    end
  end

  def render("show.json", %{conn: conn, params: params}) do
    SessionView.show(conn.assigns[:current_user], conn, params)
  end
end
