defmodule RegistrationsWeb.SpecificationController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, params) do
    specifications = Waydowntown.list_specifications()
    render(conn, "index.json", %{specifications: specifications, conn: conn, params: params})
  end
end
