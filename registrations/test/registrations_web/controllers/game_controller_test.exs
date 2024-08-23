defmodule RegistrationsWeb.GameControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Incarnation
  alias Registrations.Waydowntown.Region

  setup %{conn: conn} do
    {:ok,
     conn:
       put_req_header(conn, "accept", "application/vnd.api+json")
       |> put_req_header("content-type", "application/vnd.api+json")}
  end

  describe "show game" do
    setup do
      parent_region = Repo.insert!(%Region{name: "Parent Region"})
      child_region = Repo.insert!(%Region{name: "Child Region", parent_id: parent_region.id})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "fill_in_the_blank",
          mask: "This is a ____",
          region_id: child_region.id
        })

      {:ok, game} = Waydowntown.create_game(%{}, incarnation.concept)

      %{
        game: game,
        incarnation: incarnation,
        child_region: child_region,
        parent_region: parent_region
      }
    end

    test "returns game with nested incarnation, regions, and progress attributes", %{
      conn: conn,
      game: game,
      incarnation: incarnation,
      child_region: child_region,
      parent_region: parent_region
    } do
      conn = get(conn, Routes.game_path(conn, :show, game.id))

      assert %{
               "data" => %{
                 "id" => game_id,
                 "type" => "games",
                 "attributes" => %{
                   "complete" => false
                 },
                 "relationships" => %{
                   "incarnation" => %{
                     "data" => %{"id" => incarnation_id, "type" => "incarnations"}
                   }
                 }
               },
               "included" => included
             } = json_response(conn, 200)

      assert game_id == game.id
      assert incarnation_id == incarnation.id

      assert Enum.any?(included, fn item ->
               item["type"] == "incarnations" &&
                 item["id"] == incarnation.id &&
                 item["attributes"]["concept"] == "fill_in_the_blank" &&
                 item["attributes"]["mask"] == "This is a ____" &&
                 item["relationships"]["region"]["data"]["id"] == child_region.id
             end)

      assert Enum.any?(included, fn item ->
               item["type"] == "regions" &&
                 item["id"] == child_region.id &&
                 item["attributes"]["name"] == "Child Region" &&
                 item["relationships"]["parent"]["data"]["id"] == parent_region.id
             end)

      assert Enum.any?(included, fn item ->
               item["type"] == "regions" &&
                 item["id"] == parent_region.id &&
                 item["attributes"]["name"] == "Parent Region" &&
                 item["relationships"]["parent"]["data"] == nil
             end)
    end
  end

  describe "create game" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "fill_in_the_blank",
          mask: "This is a ____",
          region: region
        })

      %{incarnation: incarnation, region: region}
    end

    test "creates game", %{conn: conn, incarnation: incarnation} do
      conn =
        post(
          conn,
          Routes.game_path(conn, :create),
          %{
            "data" => %{
              "type" => "games",
              "attributes" => %{}
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert %{"included" => included} = json_response(conn, 201)

      sideloaded_incarnation = Enum.find(included, &(&1["type"] == "incarnations"))
      assert sideloaded_incarnation["id"] == incarnation.id

      game = Waydowntown.get_game!(id)
      assert game.incarnation_id == incarnation.id
    end

    test "creates game with filtered incarnation", %{conn: conn} do
      bluetooth_incarnation =
        Repo.insert!(%Incarnation{
          concept: "bluetooth_collector",
          region_id: Repo.insert!(%Region{}).id
        })

      conn =
        post(
          conn,
          Routes.game_path(conn, :create) <> "?filter[incarnation.concept]=bluetooth_collector",
          %{
            "data" => %{
              "type" => "games",
              "attributes" => %{}
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert %{"included" => included} = json_response(conn, 201)

      sideloaded_incarnation = Enum.find(included, &(&1["type"] == "incarnations"))
      assert sideloaded_incarnation["attributes"]["concept"] == "bluetooth_collector"

      game = Waydowntown.get_game!(id)
      assert game.incarnation_id == bluetooth_incarnation.id
    end
  end
end
