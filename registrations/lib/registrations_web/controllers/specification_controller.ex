defmodule RegistrationsWeb.SpecificationController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, params) do
    specifications = Waydowntown.list_specifications()
    render(conn, "index.json", %{specifications: specifications, conn: conn, params: params})
  end

  def mine(conn, params) do
    user = Pow.Plug.current_user(conn)
    specifications = Waydowntown.list_specifications_for(user)
    render(conn, "index.json", %{specifications: specifications, conn: conn, params: params})
  end
end
