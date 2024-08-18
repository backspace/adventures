defmodule RegistrationsWeb.AnswerControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.{Game, Incarnation, Answer, Region}

  setup %{conn: conn} do
    {:ok,
     conn:
       put_req_header(conn, "accept", "application/vnd.api+json")
       |> put_req_header("content-type", "application/vnd.api+json")}
  end

  describe "create answer for fill_in_the_blank" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "fill_in_the_blank",
          answer: "the answer",
          region: region
        })

      game = Repo.insert!(%Game{incarnation: incarnation})

      %{game: game, incarnation: incarnation, region: region}
    end

    test "creates correct answer", %{conn: conn, game: game} do
      conn =
        post(
          conn,
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => " THE ANSWER "},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      answer = Waydowntown.get_answer!(id)
      assert answer.correct == true

      game = Waydowntown.get_game!(game.id)
      assert game.winner_answer_id == answer.id

      assert %{
               "included" => [
                 %{"type" => "games", "id" => game_id, "attributes" => %{"complete" => complete}}
               ]
             } = json_response(conn, 201)

      assert game_id == game.id
      assert complete
    end

    test "does not create answer if game already has a winning answer", %{conn: conn, game: game} do
      existing_answer = Repo.insert!(%Answer{game: game})
      game = Repo.update!(Game.changeset(game, %{winner_answer_id: existing_answer.id}))

      conn =
        post(
          conn,
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => " THE ANSWER "},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "create answer for bluetooth_collector" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "bluetooth_collector",
          answers: ["device_a", "device_b"],
          region: region
        })

      game = Repo.insert!(%Game{incarnation: incarnation})

      %{game: game, incarnation: incarnation, region: region}
    end

    test "creates correct answer", %{conn: conn, game: game} do
      conn =
        post(
          conn,
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "device_a"},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      assert %{
               "included" => [
                 %{"type" => "games", "id" => game_id, "attributes" => %{"complete" => complete}}
               ]
             } = json_response(conn, 201)

      refute complete

      game = Waydowntown.get_game!(game_id)
      refute game.winner_answer_id

      answer = Waydowntown.get_answer!(id)
      assert answer.correct == true
    end

    test "creates incorrect answer", %{conn: conn, game: game} do
      conn =
        post(
          conn,
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "device_c"},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      answer = Waydowntown.get_answer!(id)
      refute answer.correct
    end
  end
end
