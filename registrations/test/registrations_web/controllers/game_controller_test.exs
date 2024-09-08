defmodule RegistrationsWeb.GameControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Incarnation
  alias Registrations.Waydowntown.Region

  setup %{conn: conn} do
    {:ok,
     conn:
       conn
       |> put_req_header("accept", "application/vnd.api+json")
       |> put_req_header("content-type", "application/vnd.api+json")}
  end

  describe "show game" do
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

      {:ok, game} = Waydowntown.create_game(%{}, %{"concept" => incarnation.concept})

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
                 item["attributes"]["description"] == "This is a ____" &&
                 item["attributes"]["placed"] == true &&
                 item["attributes"]["start"] == "Outside the coat check" &&
                 item["relationships"]["region"]["data"]["id"] == child_region.id
             end)

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

  describe "create game" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "fill_in_the_blank",
          description: "This is a ____",
          region: region,
          placed: true
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
          region_id: Repo.insert!(%Region{}).id,
          placed: true
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

    test "creates game with non-placed incarnation", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.game_path(conn, :create) <> "?filter[incarnation.placed]=false",
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
      assert sideloaded_incarnation["attributes"]["placed"] == false
      assert sideloaded_incarnation["attributes"]["concept"] in ["orientation_memory", "cardinal_memory"]
      assert sideloaded_incarnation["attributes"]["description"] != nil

      game = Waydowntown.get_game!(id)
      incarnation = Waydowntown.get_incarnation!(game.incarnation_id)
      assert incarnation.placed == false
      assert incarnation.concept in ["orientation_memory", "cardinal_memory"]
    end

    test "creates new incarnation for unplaced concept even if one exists", %{conn: conn} do
      existing_incarnation =
        Repo.insert!(%Incarnation{
          concept: "orientation_memory",
          description: "Existing description",
          region_id: Repo.insert!(%Region{}).id,
          placed: false
        })

      conn =
        post(
          conn,
          Routes.game_path(conn, :create) <> "?filter[incarnation.concept]=orientation_memory",
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
      assert sideloaded_incarnation["attributes"]["concept"] == "orientation_memory"
      assert sideloaded_incarnation["id"] != existing_incarnation.id

      game = Waydowntown.get_game!(id)
      new_incarnation = Waydowntown.get_incarnation!(game.incarnation_id)
      assert new_incarnation.id != existing_incarnation.id
      assert new_incarnation.concept == "orientation_memory"
      assert new_incarnation.placed == false
    end

    test "creates game with specific incarnation id", %{conn: conn, incarnation: incarnation} do
      conn =
        post(
          conn,
          Routes.game_path(conn, :create) <> "?filter[incarnation.id]=#{incarnation.id}",
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

    test "returns 422 when incarnation id does not exist", %{conn: conn} do
      non_existent_incarnation_id = "0de26579-1f4f-48cb-9ad5-9ed1a72f4878"

      conn =
        post(
          conn,
          Routes.game_path(conn, :create) <> "?filter[incarnation.id]=#{non_existent_incarnation_id}",
          %{
            "data" => %{
              "type" => "games",
              "attributes" => %{}
            }
          }
        )

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "creates game with nearest incarnation", %{conn: conn} do
      closer_region = Repo.insert!(%Region{name: "Region 1", geom: %Geo.Point{coordinates: {-96.1, 48.1}, srid: 4326}})
      farther_region = Repo.insert!(%Region{name: "Region 2", geom: %Geo.Point{coordinates: {-96.2, 48.2}, srid: 4326}})

      reversed_lat_lon_region =
        Repo.insert!(%Region{name: "Region 3", geom: %Geo.Point{coordinates: {48.2, -96.2}, srid: 4326}})

      closer_incarnation =
        Repo.insert!(%Incarnation{
          concept: "fill_in_the_blank",
          description: "This is a ____",
          region: closer_region,
          placed: true
        })

      Repo.insert!(%Incarnation{
        concept: "bluetooth_collector",
        region: farther_region,
        placed: true
      })

      Repo.insert!(%Incarnation{
        concept: "bluetooth_collector",
        region: reversed_lat_lon_region,
        placed: true
      })

      conn =
        post(
          conn,
          Routes.game_path(conn, :create) <> "?filter[incarnation.position]=48.0,-96.0",
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
      assert sideloaded_incarnation["id"] == closer_incarnation.id

      sideloaded_region = Enum.find(included, &(&1["type"] == "regions"))
      assert sideloaded_region["id"] == closer_region.id
      assert sideloaded_region["attributes"]["latitude"] == "48.1"
      assert sideloaded_region["attributes"]["longitude"] == "-96.1"

      game = Waydowntown.get_game!(id)
      assert game.incarnation_id == closer_incarnation.id
    end

    test "creates game with food_court_frenzy concept and virtual fields for its answer labels", %{conn: conn} do
      Repo.insert!(%Incarnation{
        concept: "food_court_frenzy",
        answers: ["Burger|6.99", "Pizza|7.99", "Salad|5.99", "Soda|3.99"],
        region: Repo.insert!(%Region{}),
        placed: true
      })

      conn =
        post(
          conn,
          Routes.game_path(conn, :create) <> "?filter[incarnation.concept]=food_court_frenzy",
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
      assert sideloaded_incarnation["attributes"]["concept"] == "food_court_frenzy"
      assert sideloaded_incarnation["attributes"]["placed"] == true

      assert Enum.all?(sideloaded_incarnation["attributes"]["answer_labels"], fn item ->
               item in ["Burger", "Pizza", "Salad", "Soda"]
             end)

      game = Waydowntown.get_game!(id)
      incarnation = Waydowntown.get_incarnation!(game.incarnation_id)
      assert incarnation.concept == "food_court_frenzy"
      assert incarnation.placed == true
    end
  end

  describe "start game" do
    setup do
      incarnation = Repo.insert!(%Incarnation{concept: "fill_in_the_blank", answers: ["answer"], duration_seconds: 300})
      {:ok, game} = Waydowntown.create_game(%{}, %{"concept" => incarnation.concept})
      %{game: game}
    end

    test "starts the game", %{conn: conn, game: game} do
      conn = post(conn, Routes.game_start_path(conn, :start, game), %{"data" => %{"type" => "games", "id" => game.id}})
      assert %{"data" => %{"id" => _id, "attributes" => %{"started_at" => started_at}}} = json_response(conn, 200)
      assert started_at != nil
    end

    test "returns error when starting an already started game", %{conn: conn, game: game} do
      Waydowntown.start_game(game)
      conn = post(conn, Routes.game_start_path(conn, :start, game), %{"data" => %{"type" => "games", "id" => game.id}})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end
end
