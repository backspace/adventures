defmodule RegistrationsWeb.IncarnationControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown.Incarnation
  alias Registrations.Waydowntown.Region

  setup %{conn: conn} do
    {:ok,
     conn:
       conn
       |> put_req_header("accept", "application/vnd.api+json")
       |> put_req_header("content-type", "application/vnd.api+json")}
  end

  describe "list incarnations" do
    setup do
      parent_region =
        Repo.insert!(%Region{name: "Parent Region", geom: %Geo.Point{coordinates: {-97.0, 40.1}, srid: 4326}})

      child_region =
        Repo.insert!(%Region{
          name: "Child Region",
          parent_id: parent_region.id,
          geom: %Geo.Point{coordinates: {-97.143130, 49.891725}, srid: 4326}
        })

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "fill_in_the_blank",
          description: "This is a ____",
          region_id: child_region.id,
          placed: true,
          start: "Outside the coat check"
        })

      %{
        incarnation: incarnation,
        child_region: child_region,
        parent_region: parent_region
      }
    end

    test "returns list of incarnations with nested regions", %{
      conn: conn,
      incarnation: incarnation,
      child_region: child_region,
      parent_region: parent_region
    } do
      conn = get(conn, Routes.incarnation_path(conn, :index))

      assert %{
               "data" => [incarnation_data | _],
               "included" => included
             } = json_response(conn, 200)

      assert incarnation_data["id"] == incarnation.id
      assert incarnation_data["type"] == "incarnations"
      assert incarnation_data["attributes"]["concept"] == "fill_in_the_blank"
      assert incarnation_data["attributes"]["placed"] == true
      assert incarnation_data["attributes"]["start"] == "Outside the coat check"
      assert incarnation_data["relationships"]["region"]["data"]["id"] == child_region.id

      assert Enum.any?(included, fn item ->
               item["type"] == "regions" &&
                 item["id"] == child_region.id &&
                 item["attributes"]["name"] == "Child Region" &&
                 item["relationships"]["parent"]["data"]["id"] == parent_region.id &&
                 item["attributes"]["latitude"] == "49.891725" &&
                 item["attributes"]["longitude"] == "-97.14313"
             end)

      assert Enum.any?(included, fn item ->
               item["type"] == "regions" &&
                 item["id"] == parent_region.id &&
                 item["attributes"]["name"] == "Parent Region" &&
                 item["attributes"]["latitude"] == "40.1" &&
                 item["attributes"]["longitude"] == "-97.0" &&
                 item["relationships"]["parent"]["data"] == nil
             end)
    end
  end
end
