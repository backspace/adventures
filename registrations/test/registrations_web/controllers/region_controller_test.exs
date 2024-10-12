defmodule RegistrationsWeb.RegionControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown.Region

  defp setup_conn(conn) do
    conn
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("content-type", "application/vnd.api+json")
  end

  describe "GET /waydowntown/regions" do
    setup do
      parent_region =
        Repo.insert!(%Region{name: "Parent Region", geom: %Geo.Point{coordinates: {-97.0, 40.1}, srid: 4326}})

      child_region =
        Repo.insert!(%Region{
          name: "Child Region",
          parent_id: parent_region.id,
          geom: %Geo.Point{coordinates: {-97.143130, 49.891725}, srid: 4326}
        })

      root_region = Repo.insert!(%Region{name: "Root Region", geom: %Geo.Point{coordinates: {-97.0, 40.1}, srid: 4326}})

      %{parent_region: parent_region, child_region: child_region, root_region: root_region}
    end

    test "lists all regions", %{conn: conn} do
      conn = get(conn, Routes.region_path(conn, :index))
      data = json_response(conn, 200)["data"]

      assert length(data) == 3
    end
  end
end
