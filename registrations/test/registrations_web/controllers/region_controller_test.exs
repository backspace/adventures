defmodule RegistrationsWeb.RegionControllerTest do
  use RegistrationsWeb.ConnCase

  import Registrations.WaydowntownFixtures

  alias Registrations.Waydowntown.Region

  @create_attrs %{
    description: "some description",
    name: "some name"
  }
  @update_attrs %{
    description: "some updated description",
    name: "some updated name"
  }
  @invalid_attrs %{description: nil, name: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all regions", %{conn: conn} do
      conn = get(conn, Routes.region_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create region" do
    test "renders region when data is valid", %{conn: conn} do
      conn = post(conn, Routes.region_path(conn, :create), region: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.region_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "description" => "some description",
               "name" => "some name"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.region_path(conn, :create), region: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update region" do
    setup [:create_region]

    test "renders region when data is valid", %{conn: conn, region: %Region{id: id} = region} do
      conn = put(conn, Routes.region_path(conn, :update, region), region: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.region_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "description" => "some updated description",
               "name" => "some updated name"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, region: region} do
      conn = put(conn, Routes.region_path(conn, :update, region), region: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete region" do
    setup [:create_region]

    test "deletes chosen region", %{conn: conn, region: region} do
      conn = delete(conn, Routes.region_path(conn, :delete, region))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.region_path(conn, :show, region))
      end
    end
  end

  defp create_region(_) do
    region = region_fixture()
    %{region: region}
  end
end
