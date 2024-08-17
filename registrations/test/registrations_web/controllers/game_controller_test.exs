defmodule RegistrationsWeb.GameControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Game
  alias Registrations.Waydowntown.Incarnation
  alias Registrations.Waydowntown.Region

  require Logger

  setup %{conn: conn} do
    Logger.info("Setting up test environment with header")

    {:ok,
     conn:
       put_req_header(conn, "accept", "application/vnd.api+json")
       |> put_req_header("content-type", "application/vnd.api+json")}
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
          Routes.game_path(conn, :create) <> "?incarnation_filter[concept]=bluetooth_collector",
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
