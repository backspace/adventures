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

  describe "GET /waydowntown/regions with position filter" do
    setup do
      regions = [
        %{name: "Region 1", coordinates: {-97.1, 49.9}},
        %{name: "Region 2", coordinates: {-97.2, 49.8}},
        %{name: "Region 3", coordinates: {-97.3, 49.7}},
        %{name: "Region 4", coordinates: {-97.4, 49.6}},
        %{name: "Region 5", coordinates: {-97.5, 49.5}},
        %{name: "Region 6", coordinates: {-97.6, 49.4}},
        %{name: "Region 7", coordinates: {-97.7, 49.3}},
        %{name: "Region 8", coordinates: {-97.8, 49.2}},
        %{name: "Region 9", coordinates: {-97.9, 49.1}},
        %{name: "Region 10", coordinates: {-98.0, 49.0}},
        %{name: "Region 11", coordinates: {-98.1, 48.9}}
      ]

      Enum.each(regions, fn region ->
        Repo.insert!(%Region{
          name: region.name,
          geom: %Geo.Point{coordinates: region.coordinates, srid: 4326}
        })
      end)

      :ok
    end

    test "returns the closest 10 regions sorted by distance", %{conn: conn} do
      conn = get(conn, Routes.region_path(conn, :index) <> "?filter[position]=49.9,-97.1")
      data = json_response(conn, 200)["data"]

      assert length(data) == 10

      # FIXME this should already be sorted but something goes awry when serialising
      regions_sorted_by_distance = Enum.sort_by(data, & &1["attributes"]["distance"])

      assert Enum.map(regions_sorted_by_distance, & &1["attributes"]["name"]) == [
               "Region 1",
               "Region 2",
               "Region 3",
               "Region 4",
               "Region 5",
               "Region 6",
               "Region 7",
               "Region 8",
               "Region 9",
               "Region 10"
             ]
    end
  end
end
