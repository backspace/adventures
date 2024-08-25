defmodule RegistrationsWeb.AnswerControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Game
  alias Registrations.Waydowntown.Incarnation
  alias Registrations.Waydowntown.Region

  setup %{conn: conn} do
    {:ok,
     conn:
       conn
       |> put_req_header("accept", "application/vnd.api+json")
       |> put_req_header("content-type", "application/vnd.api+json")}
  end

  describe "create answer for fill_in_the_blank" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "fill_in_the_blank",
          answers: ["the answer"],
          region: region,
          placed: true
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
      assert answer.correct

      game = Waydowntown.get_game!(game.id)
      assert game.winner_answer_id == answer.id

      assert %{
               "included" => [
                 %{
                   "type" => "incarnations",
                   "id" => _incarnation_id,
                   "attributes" => _incarnation_attributes
                 },
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

    test "returns 422 when updating an incorrect answer", %{conn: conn, game: game} do
      # First, create an incorrect answer
      conn =
        post(
          conn,
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "WRONG ANSWER"},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      # Now, try to update the incorrect answer
      conn =
        patch(
          conn,
          Routes.answer_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "answers",
              "attributes" => %{"answer" => "ANOTHER WRONG ANSWER"},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Cannot update an incorrect answer"}]
    end
  end

  describe "create answer for non-placed incarnation" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "orientation_memory",
          answers: ["left", "up", "right"],
          region: region,
          placed: false
        })

      game = Repo.insert!(%Game{incarnation: incarnation})

      %{game: game, incarnation: incarnation, region: region}
    end

    test "creates and updates answer", %{conn: conn, game: game} do
      # Create initial answer
      conn =
        post(
          conn,
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "left"},
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
      assert answer.answer == "left"
      assert answer.correct

      # Update the answer
      conn =
        patch(
          conn,
          Routes.answer_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "answers",
              "attributes" => %{"answer" => "left|up"},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      updated_answer = Waydowntown.get_answer!(id)
      assert updated_answer.answer == "left|up"
      assert updated_answer.correct

      # Complete the answer
      conn =
        patch(
          conn,
          Routes.answer_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "answers",
              "attributes" => %{"answer" => "left|up|right"},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      completed_answer = Waydowntown.get_answer!(id)
      assert completed_answer.answer == "left|up|right"
      assert completed_answer.correct

      game = Waydowntown.get_game!(game.id)
      assert game.winner_answer_id == completed_answer.id
    end
  end

  describe "create answer for bluetooth_collector" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "bluetooth_collector",
          answers: ["device_a", "device_b"],
          region: region,
          placed: true
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
      answer = Waydowntown.get_answer!(id)
      assert answer.correct

      game = Waydowntown.get_game!(game.id)
      refute game.winner_answer_id
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

  describe "create answer for code_collector" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "code_collector",
          answers: ["code_a", "code_b"],
          region: region,
          placed: true
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
              "attributes" => %{"answer" => "code_a"},
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
      assert answer.correct

      game = Waydowntown.get_game!(game.id)
      refute game.winner_answer_id
    end

    test "creates incorrect answer", %{conn: conn, game: game} do
      conn =
        post(
          conn,
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "code_c"},
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
