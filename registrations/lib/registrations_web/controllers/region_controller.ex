defmodule RegistrationsWeb.RegionController do
  use RegistrationsWeb, :controller

  plug(JSONAPI.QueryParser, view: RegistrationsWeb.RegionView)

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Region

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, _params) do
    regions = Waydowntown.list_regions()
    render(conn, "index.json", regions: regions)
  end

  def create(conn, %{"region" => region_params}) do
    with {:ok, %Region{} = region} <- Waydowntown.create_region(region_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.region_path(conn, :show, region))
      |> render("show.json", region: region)
    end
  end

  def show(conn, %{"id" => id}) do
    region = Waydowntown.get_region!(id)
    render(conn, "show.json", %{region: region, conn: conn, params: conn.params})
  end

  def update(conn, %{"id" => id, "region" => region_params}) do
    region = Waydowntown.get_region!(id)

    with {:ok, %Region{} = region} <- Waydowntown.update_region(region, region_params) do
      render(conn, "show.json", region: region)
    end
  end

  def delete(conn, %{"id" => id}) do
    region = Waydowntown.get_region!(id)

    with {:ok, %Region{}} <- Waydowntown.delete_region(region) do
      send_resp(conn, :no_content, "")
    end
  end
end
