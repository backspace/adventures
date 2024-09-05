defmodule RegistrationsWeb.AnswerControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Game
  alias Registrations.Waydowntown.Incarnation
  alias Registrations.Waydowntown.Region

  defp setup_conn(conn) do
    conn
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("content-type", "application/vnd.api+json")
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
        conn
        |> setup_conn()
        |> post(
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
        conn
        |> setup_conn()
        |> post(
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

    test "fails to update an existing answer for a placed incarnation", %{conn: conn, game: game} do
      # First, create an answer
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "THE ANSWER"},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      # Now, try to update the answer
      conn =
        build_conn()
        |> setup_conn()
        |> patch(
          Routes.answer_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "answers",
              "attributes" => %{"answer" => "UPDATED ANSWER"},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Cannot update answer for placed incarnation"}]
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
        build_conn()
        |> setup_conn()
        |> post(
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
        build_conn()
        |> setup_conn()
        |> patch(
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
        build_conn()
        |> setup_conn()
        |> patch(
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

    test "always creates a new answer on POST, even if incorrect", %{conn: conn, game: game} do
      conn =
        build_conn()
        |> setup_conn()
        |> post(
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
      answer = Waydowntown.get_answer!(id)
      assert answer.answer == "WRONG ANSWER"
      refute answer.correct
    end

    test "returns 422 when updating an incorrect answer", %{conn: conn, game: game} do
      # First, create an incorrect answer
      conn =
        conn
        |> setup_conn()
        |> post(
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
        build_conn()
        |> setup_conn()
        |> patch(
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
        conn
        |> setup_conn()
        |> post(
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
        conn
        |> setup_conn()
        |> post(
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
        conn
        |> setup_conn()
        |> post(
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
        conn
        |> setup_conn()
        |> post(
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

  describe "create answer for cardinal_memory" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "cardinal_memory",
          answers: ["north", "east", "south"],
          region: region,
          placed: false
        })

      game = Repo.insert!(%Game{incarnation: incarnation})

      %{game: game, incarnation: incarnation, region: region}
    end

    test "creates and updates answer", %{conn: conn, game: game} do
      conn =
        build_conn()
        |> setup_conn()
        |> post(
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "north"},
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
      assert answer.answer == "north"
      assert answer.correct

      conn =
        build_conn()
        |> setup_conn()
        |> patch(
          Routes.answer_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "answers",
              "attributes" => %{"answer" => "north|east"},
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
      assert updated_answer.answer == "north|east"
      assert updated_answer.correct

      conn =
        build_conn()
        |> setup_conn()
        |> patch(
          Routes.answer_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "answers",
              "attributes" => %{"answer" => "north|east|south"},
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
      assert completed_answer.answer == "north|east|south"
      assert completed_answer.correct

      game = Waydowntown.get_game!(game.id)
      assert game.winner_answer_id == completed_answer.id
    end

    test "always creates a new answer on POST, even if incorrect", %{conn: conn, game: game} do
      conn =
        build_conn()
        |> setup_conn()
        |> post(
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
      answer = Waydowntown.get_answer!(id)
      assert answer.answer == "WRONG ANSWER"
      refute answer.correct
    end

    test "returns 422 when updating an incorrect answer", %{conn: conn, game: game} do
      conn =
        conn
        |> setup_conn()
        |> post(
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

      conn =
        build_conn()
        |> setup_conn()
        |> patch(
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

  describe "create answer for string_collector" do
    setup do
      incarnation =
        Repo.insert!(%Incarnation{
          concept: "string_collector",
          mask: "Collect all the strings",
          answers: ["first string", "second string", "THIRD string"],
          placed: true
        })

      game = Repo.insert!(%Game{incarnation: incarnation})

      %{game: game}
    end

    test "creates answer and returns 201 for correct answer", %{conn: conn, game: game} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "  First String  "},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert %{"correct" => true} = json_response(conn, 201)["data"]["attributes"]
    end

    test "creates answer and returns 201 for incorrect answer", %{conn: conn, game: game} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "Wrong String"},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            },
            "game_id" => game.id
          }
        )

      assert %{"correct" => false} = json_response(conn, 201)["data"]["attributes"]
    end

    test "completes game when all strings are collected, correct answers are normalised", %{game: game} do
      Enum.each(["First String", "SECOND string", "  third STRING  "], fn answer ->
        conn =
          setup_conn(build_conn())

        post(conn, Routes.answer_path(conn, :create), %{
          "data" => %{
            "type" => "answers",
            "attributes" => %{"answer" => answer},
            "relationships" => %{
              "game" => %{
                "data" => %{"type" => "games", "id" => game.id}
              }
            }
          }
        })
      end)

      updated_game = Waydowntown.get_game!(game.id)

      assert updated_game.winner_answer_id != nil
    end

    test "rejects a duplicate answer", %{conn: conn, game: game} do
      Repo.insert!(%Answer{
        answer: "first string",
        game_id: game.id,
        correct: true
      })

      conn =
        conn
        |> setup_conn()
        |> post(Routes.answer_path(conn, :create), %{
          "data" => %{
            "type" => "answers",
            "attributes" => %{"answer" => " first string "},
            "relationships" => %{
              "game" => %{
                "data" => %{"type" => "games", "id" => game.id}
              }
            }
          }
        })

      assert json_response(conn, 422)["errors"] == %{"detail" => ["Answer already submitted"]}
    end
  end

  describe "create answer for count_the_items" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "count_the_items",
          answers: ["42"],
          region: region,
          placed: true
        })

      game = Repo.insert!(%Game{incarnation: incarnation})

      %{game: game, incarnation: incarnation, region: region}
    end

    test "creates correct answer", %{conn: conn, game: game} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "42"},
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

    test "creates incorrect answer", %{conn: conn, game: game} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "24"},
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

  describe "create answer for food_court_frenzy" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      incarnation =
        Repo.insert!(%Incarnation{
          concept: "food_court_frenzy",
          answers: ["burger|5.99", "fries|2.99", "soda|1.99"],
          region: region,
          placed: true
        })

      game = Repo.insert!(%Game{incarnation: incarnation})

      %{game: game, incarnation: incarnation, region: region}
    end

    test "creates correct answer", %{conn: conn, game: game} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "burger|5.99"},
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
        conn
        |> setup_conn()
        |> post(
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "burger|6.99"},
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

    test "returns 422 when submitting an unknown label", %{conn: conn, game: game} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "unknown|5.99"},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] == %{"detail" => ["Unknown label: unknown"]}
    end

    test "returns 422 when submitting an answer for a label that already had a correct answer", %{conn: conn, game: game} do
      # Submit a correct answer
      conn
      |> setup_conn()
      |> post(
        Routes.answer_path(conn, :create),
        %{
          "data" => %{
            "type" => "answers",
            "attributes" => %{"answer" => "burger|5.99"},
            "relationships" => %{
              "game" => %{
                "data" => %{"type" => "games", "id" => game.id}
              }
            }
          }
        }
      )

      # Submit another answer for the same label
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.answer_path(conn, :create),
          %{
            "data" => %{
              "type" => "answers",
              "attributes" => %{"answer" => "burger|6.99"},
              "relationships" => %{
                "game" => %{
                  "data" => %{"type" => "games", "id" => game.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] == %{"detail" => ["Answer already submitted for label: burger"]}
    end
  end
end
