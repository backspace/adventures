defmodule RegistrationsWeb.IncarnationController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, params) do
    incarnations = Waydowntown.list_incarnations()
    render(conn, "index.json", %{incarnations: incarnations, conn: conn, params: params})
  end
end
