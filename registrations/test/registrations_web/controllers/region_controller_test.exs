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

  describe "POST /waydowntown/regions" do
    setup %{conn: conn} do
      %{authorization_token: setup_user_and_get_token(), conn: setup_conn(conn)}
    end

    test "creates and renders region", %{authorization_token: authorization_token, conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", authorization_token)
        |> post(Routes.region_path(conn, :create),
          data: %{
            type: "regions",
            attributes: %{
              name: "New Region",
              description: "New Region Description",
              geom: %{
                type: "Point",
                coordinates: [-97.143130, 49.891725],
                srid: 4326
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      region = Repo.get!(Region, id)

      assert region.name == "New Region"
      assert region.description == "New Region Description"
      assert region.geom.coordinates == {-97.143130, 49.891725}
    end

    test "renders errors when data is invalid", %{authorization_token: authorization_token, conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", authorization_token)
        |> post(Routes.region_path(conn, :create), data: %{type: "regions", attributes: %{}})

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "PATCH /waydowntown/regions/:id" do
    setup %{conn: conn} do
      region = Repo.insert!(%Region{name: "Test Region", geom: %Geo.Point{coordinates: {-97.0, 40.1}, srid: 4326}})
      %{authorization_token: setup_user_and_get_token(), conn: setup_conn(conn), region: region}
    end

    test "updates and renders region", %{
      authorization_token: authorization_token,
      conn: conn,
      region: region
    } do
      conn =
        conn
        |> put_req_header("authorization", authorization_token)
        |> patch(
          Routes.region_path(conn, :update, region),
          %{
            "data" => %{
              "type" => "regions",
              "id" => region.id,
              "attributes" => %{
                "name" => "Updated Region"
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 200)["data"]

      updated_region = Repo.get!(Region, id)

      assert updated_region.name == "Updated Region"
    end

    test "renders errors when data is invalid", %{authorization_token: authorization_token, conn: conn, region: region} do
      conn =
        conn
        |> put_req_header("authorization", authorization_token)
        |> patch(
          Routes.region_path(conn, :update, region),
          %{
            "data" => %{
              "type" => "regions",
              "id" => region.id,
              "attributes" => %{
                "name" => nil
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "DELETE /waydowntown/regions/:id" do
    setup %{conn: conn} do
      region = Repo.insert!(%Region{name: "Test Region", geom: %Geo.Point{coordinates: {-97.0, 40.1}, srid: 4326}})
      %{conn: setup_conn(conn), region: region}
    end

    test "deletes chosen region when user is admin", %{conn: conn, region: region} do
      admin_token = setup_user_and_get_token(admin: true)

      conn =
        conn
        |> put_req_header("authorization", admin_token)
        |> delete(Routes.region_path(conn, :delete, region))

      assert response(conn, 204)
      assert_raise Ecto.NoResultsError, fn -> Repo.get!(Region, region.id) end
    end

    test "returns forbidden when user is not admin", %{conn: conn, region: region} do
      non_admin_token = setup_user_and_get_token(admin: false)

      conn =
        conn
        |> put_req_header("authorization", non_admin_token)
        |> delete(Routes.region_path(conn, :delete, region))

      assert json_response(conn, 403)["errors"] == [
               %{"detail" => "Admin access required", "status" => 403, "title" => "Forbidden"}
             ]

      # Region still exists
      assert Repo.get!(Region, region.id)
    end
  end

  defp setup_user_and_get_token(opts \\ []) do
    user = insert(:octavia, admin: Keyword.get(opts, :admin, true))

    authed_conn = build_conn()

    authed_conn =
      post(authed_conn, Routes.api_session_path(authed_conn, :create), %{
        "user" => %{"email" => user.email, "password" => "Xenogenesis"}
      })

    json = json_response(authed_conn, 200)

    json["data"]["access_token"]
  end
end
