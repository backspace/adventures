defmodule RegistrationsWeb.RegionController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown

  def index(conn, params) do
    regions = Waydowntown.list_regions()
    render(conn, "index.json", %{regions: regions, conn: conn, params: params})
  end
end
