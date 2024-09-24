defmodule RegistrationsWeb.SpecificationControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown.Region
  alias Registrations.Waydowntown.Specification

  setup %{conn: conn} do
    {:ok,
     conn:
       conn
       |> put_req_header("accept", "application/vnd.api+json")
       |> put_req_header("content-type", "application/vnd.api+json")}
  end

  describe "list specifications" do
    setup do
      parent_region =
        Repo.insert!(%Region{name: "Parent Region", geom: %Geo.Point{coordinates: {-97.0, 40.1}, srid: 4326}})

      child_region =
        Repo.insert!(%Region{
          name: "Child Region",
          parent_id: parent_region.id,
          geom: %Geo.Point{coordinates: {-97.143130, 49.891725}, srid: 4326}
        })

      specification =
        Repo.insert!(%Specification{
          concept: "fill_in_the_blank",
          task_description: "This is a ____",
          region_id: child_region.id,
          start_description: "Outside the coat check"
        })

      Repo.insert!(%Specification{
        concept: "orientation_memory"
      })

      %{
        specification: specification,
        child_region: child_region,
        parent_region: parent_region
      }
    end

    test "returns list of specifications with nested regions", %{
      conn: conn,
      specification: specification,
      child_region: child_region,
      parent_region: parent_region
    } do
      conn = get(conn, Routes.specification_path(conn, :index))

      assert %{
               "data" => [placed_specification_data, unplaced_specification_data | _],
               "included" => included
             } = json_response(conn, 200)

      assert placed_specification_data["id"] == specification.id
      assert placed_specification_data["type"] == "specifications"
      assert placed_specification_data["attributes"]["placed"]
      assert placed_specification_data["attributes"]["concept"] == "fill_in_the_blank"
      assert placed_specification_data["attributes"]["start_description"] == "Outside the coat check"
      assert placed_specification_data["relationships"]["region"]["data"]["id"] == child_region.id

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

      refute unplaced_specification_data["attributes"]["placed"]
    end
  end

  describe "list my specifications" do
    setup do
      user = insert(:octavia, admin: true)
      my_specification_1 = Repo.insert!(%Specification{creator_id: user.id})
      my_specification_2 = Repo.insert!(%Specification{creator_id: user.id})
      other_specification = Repo.insert!(%Specification{creator_id: insert(:user).id})

      authed_conn = build_conn()

      authed_conn =
        authed_conn
        |> post(Routes.api_session_path(authed_conn, :create), %{"user" => %{"email" => user.email, "password" => "Xenogenesis"}})

      json = json_response(authed_conn, 200)
      authorization_token = json["data"]["access_token"]

      %{authorization_token: authorization_token, my_specification_1: my_specification_1, my_specification_2: my_specification_2, other_specification: other_specification, user: user}
    end

    test "returns list of specifications for the current user", %{
      conn: conn,
      authorization_token: authorization_token,
      my_specification_1: my_specification_1,
      my_specification_2: my_specification_2,
      other_specification: other_specification,
    } do
      conn =
        conn
        |> put_req_header("authorization", "#{authorization_token}")
        |> get(Routes.my_specifications_path(conn, :mine))

      response_specification_ids =
        json_response(conn, 200)
        |> Map.get("data")
        |> Enum.map(fn specification -> specification["id"] end)

      assert my_specification_1.id in response_specification_ids
      assert my_specification_2.id in response_specification_ids
      refute other_specification.id in response_specification_ids
    end
  end
end
