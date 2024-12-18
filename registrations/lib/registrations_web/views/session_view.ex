defmodule RegistrationsWeb.SessionView do
  use JSONAPI.View, type: "session"

  alias RegistrationsWeb.SessionView

  def fields do
    [:admin, :email, :name]
  end

  def render("show.json", %{conn: conn, params: params}) do
    SessionView.show(conn.assigns[:current_user], conn, params)
  end
end
