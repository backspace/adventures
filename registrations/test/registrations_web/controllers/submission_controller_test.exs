defmodule RegistrationsWeb.SubmissionControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Region
  alias Registrations.Waydowntown.Run
  alias Registrations.Waydowntown.Specification
  alias Registrations.Waydowntown.Submission

  defp setup_conn(conn) do
    conn
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("content-type", "application/vnd.api+json")
  end

  describe "create submission" do
    setup do
      specification =
        Repo.insert!(%Specification{
          concept: "fill_in_the_blank",
          answers: [%Answer{answer: "the answer"}],
          duration: 300
        })

      run = Repo.insert!(%Run{specification: specification})

      %{run: run}
    end

    test "returns error when run has not been started", %{conn: conn, run: run} do
      conn =
        conn
        |> setup_conn()
        |> post(Routes.submission_path(conn, :create), %{
          "data" => %{
            "type" => "submissions",
            "attributes" => %{"submission" => "test submission"},
            "relationships" => %{
              "run" => %{"data" => %{"type" => "runs", "id" => run.id}}
            }
          }
        })

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Run has not been started"}]
    end

    test "returns error when run has expired", %{conn: conn, run: run} do
      expired_run =
        run |> Ecto.Changeset.change(started_at: DateTime.add(DateTime.utc_now(), -301, :second)) |> Repo.update!()

      conn =
        conn
        |> setup_conn()
        |> post(Routes.submission_path(conn, :create), %{
          "data" => %{
            "type" => "submissions",
            "attributes" => %{"submission" => "test submission"},
            "relationships" => %{
              "run" => %{"data" => %{"type" => "runs", "id" => expired_run.id}}
            }
          }
        })

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Run has expired"}]
    end
  end

  describe "create submission for fill_in_the_blank" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      specification =
        Repo.insert!(%Specification{
          concept: "fill_in_the_blank",
          answers: [%Answer{label: "fill in ___ ______", answer: "the answer"}],
          region: region
        })

      run = Repo.insert!(%Run{specification: specification, started_at: DateTime.utc_now()})

      answer = List.first(specification.answers)

      %{run: run, specification: specification, region: region, answer: answer}
    end

    test "creates correct submission", %{conn: conn, run: run, answer: answer} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => " THE ANSWER "},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => answer.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      assert submission.submission == " THE ANSWER "
      assert submission.answer_id == answer.id
      assert submission.correct

      run = Waydowntown.get_run!(run.id)
      assert run.winner_submission_id == submission.id

      included = json_response(conn, 201)["included"]

      assert %{"included" => included} = json_response(conn, 201)

      sideloaded_specification = Enum.find(included, &(&1["type"] == "specifications"))
      assert sideloaded_specification["id"] == run.specification.id

      sideloaded_run = Enum.find(included, &(&1["type"] == "runs"))
      assert sideloaded_run["id"] == run.id
      assert sideloaded_run["attributes"]["complete"]

      sideloaded_answer = Enum.find(included, &(&1["type"] == "answers"))
      assert sideloaded_answer["id"] == answer.id
    end

    test "does not create submission if run already has a winning submission", %{conn: conn, run: run} do
      existing_submission = Repo.insert!(%Submission{run: run})
      run = Repo.update!(Run.changeset(run, %{winner_submission_id: existing_submission.id}))

      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => " THE ANSWER "},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "create submission for non-placed specifications" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      specification =
        Repo.insert!(%Specification{
          # Tried to loop through both… should be identical
          concept: Enum.random(["orientation_memory", "cardinal_memory"]),
          answers: [
            %Answer{order: 1, answer: "left"},
            %Answer{order: 2, answer: "up"},
            %Answer{order: 3, answer: "right"}
          ],
          region: region
        })

      run = Repo.insert!(%Run{specification: specification, started_at: DateTime.utc_now()})

      %{run: run, specification: specification, region: region}
    end

    test "creates submissions and completes the run", %{conn: conn, run: run, specification: specification} do
      [answer_1, answer_2, answer_3] = specification.answers

      conn =
        build_conn()
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => answer_1.answer},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => answer_1.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      assert submission.submission == answer_1.answer
      assert submission.correct

      conn =
        build_conn()
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "id" => id,
              "type" => "submissions",
              "attributes" => %{"submission" => answer_2.answer},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => answer_2.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      created_submission = Waydowntown.get_submission!(id)
      assert created_submission.submission == answer_2.answer
      assert created_submission.correct

      conn =
        build_conn()
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "id" => id,
              "type" => "submissions",
              "attributes" => %{"submission" => answer_3.answer},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => answer_3.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      completed_submission = Waydowntown.get_submission!(id)
      assert completed_submission.submission == answer_3.answer
      assert completed_submission.correct

      run = Waydowntown.get_run!(run.id)
      assert run.winner_submission_id == completed_submission.id
    end

    test "creates incorrect first submission", %{conn: conn, run: run, specification: specification} do
      answer_1 = List.first(specification.answers)

      conn =
        build_conn()
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "WRONG ANSWER"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => answer_1.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      assert submission.submission == "WRONG ANSWER"
      refute submission.correct
    end

    test "returns 422 when answer is not in correct order", %{conn: conn, run: run, specification: specification} do
      [answer_1, answer_2, answer_3] = specification.answers

      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "WRONG ANSWER"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => answer_2.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] == [
               %{"detail" => "Expected submission for answer of order 1, id #{answer_1.id}"}
             ]

      conn =
        build_conn()
        |> setup_conn()
        |> post(Routes.submission_path(conn, :create), %{
          "data" => %{
            "type" => "submissions",
            "attributes" => %{"submission" => answer_1.answer},
            "relationships" => %{
              "run" => %{
                "data" => %{"type" => "runs", "id" => run.id}
              },
              "answer" => %{
                "data" => %{"type" => "answers", "id" => answer_1.id}
              }
            }
          }
        })

      conn =
        build_conn()
        |> setup_conn()
        |> post(Routes.submission_path(conn, :create), %{
          "data" => %{
            "type" => "submissions",
            "attributes" => %{"submission" => answer_1.answer},
            "relationships" => %{
              "run" => %{
                "data" => %{"type" => "runs", "id" => run.id}
              },
              "answer" => %{
                "data" => %{"type" => "answers", "id" => answer_1.id}
              }
            }
          }
        })

      assert json_response(conn, 422)["errors"] == [
               %{"detail" => "Expected submission for answer of order 2, id #{answer_2.id}"}
             ]
    end

    test "returns 422 when answer does not belong to specification", %{conn: conn, run: run, specification: specification} do
      other_specification =
        Repo.insert!(%Specification{concept: "other_concept", answers: [%Answer{answer: "other_answer"}]})

      other_answer = List.first(other_specification.answers)

      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "left"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => other_answer.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Answer does not belong to specification"}]
    end
  end

  describe "create submission for bluetooth_collector" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      specification =
        Repo.insert!(%Specification{
          concept: "bluetooth_collector",
          answers: [%Answer{answer: "device_a"}, %Answer{answer: "device_b"}],
          region: region
        })

      run = Repo.insert!(%Run{specification: specification, started_at: DateTime.utc_now()})

      %{run: run, specification: specification, region: region}
    end

    test "creates correct submission", %{conn: conn, run: run} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "device_a"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      assert submission.submission == "device_a"
      assert submission.correct

      run = Waydowntown.get_run!(run.id)
      refute run.winner_submission_id
    end

    test "creates incorrect submission", %{conn: conn, run: run} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "device_c"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      refute submission.correct
    end
  end

  describe "create submission for code_collector" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      specification =
        Repo.insert!(%Specification{
          concept: "code_collector",
          answers: [%Answer{answer: "code_a"}, %Answer{answer: "code_b"}],
          region: region
        })

      run = Repo.insert!(%Run{specification: specification, started_at: DateTime.utc_now()})

      %{run: run, specification: specification, region: region}
    end

    test "creates correct submission", %{conn: conn, run: run} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "code_a"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      assert submission.correct

      run = Waydowntown.get_run!(run.id)
      refute run.winner_submission_id
    end

    test "creates incorrect submission", %{conn: conn, run: run} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "code_c"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      refute submission.correct
    end
  end

  describe "create submission for string_collector" do
    setup do
      specification =
        Repo.insert!(%Specification{
          concept: "string_collector",
          start_description: "Collect all the strings",
          answers: [%Answer{answer: "first string"}, %Answer{answer: "second string"}, %Answer{answer: "THIRD string"}]
        })

      run = Repo.insert!(%Run{specification: specification, started_at: DateTime.utc_now()})

      %{run: run}
    end

    test "creates answer and returns 201 for correct submission", %{conn: conn, run: run} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "  First String  "},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert %{"correct" => true} = json_response(conn, 201)["data"]["attributes"]
    end

    test "creates answer and returns 201 for incorrect submission", %{conn: conn, run: run} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "Wrong String"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            },
            "run_id" => run.id
          }
        )

      assert %{"correct" => false} = json_response(conn, 201)["data"]["attributes"]
    end

    test "completes run when all strings are collected, correct answers are normalised", %{run: run} do
      Enum.each(["First String", "SECOND string", "  third STRING  "], fn submission ->
        conn =
          setup_conn(build_conn())

        post(conn, Routes.submission_path(conn, :create), %{
          "data" => %{
            "type" => "submissions",
            "attributes" => %{"submission" => submission},
            "relationships" => %{
              "run" => %{
                "data" => %{"type" => "runs", "id" => run.id}
              }
            }
          }
        })
      end)

      updated_run = Waydowntown.get_run!(run.id)

      assert updated_run.winner_submission_id != nil
    end

    test "rejects a duplicate submission", %{conn: conn, run: run} do
      Repo.insert!(%Submission{
        submission: "first string",
        run_id: run.id,
        correct: true
      })

      conn =
        conn
        |> setup_conn()
        |> post(Routes.submission_path(conn, :create), %{
          "data" => %{
            "type" => "submissions",
            "attributes" => %{"submission" => " first string "},
            "relationships" => %{
              "run" => %{
                "data" => %{"type" => "runs", "id" => run.id}
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

      specification =
        Repo.insert!(%Specification{
          concept: "count_the_items",
          answers: [%Answer{label: "how many?", answer: "42"}],
          region: region
        })

      run = Repo.insert!(%Run{specification: specification, started_at: DateTime.utc_now()})

      answer = List.first(specification.answers)

      %{run: run, specification: specification, region: region, answer: answer}
    end

    test "creates correct submission", %{conn: conn, run: run, answer: answer} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "42"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => answer.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      assert submission.correct

      run = Waydowntown.get_run!(run.id)
      assert run.winner_submission_id == submission.id

      included = json_response(conn, 201)["included"]

      assert %{"included" => included} = json_response(conn, 201)

      sideloaded_specification = Enum.find(included, &(&1["type"] == "specifications"))
      assert sideloaded_specification["id"] == run.specification.id

      sideloaded_run = Enum.find(included, &(&1["type"] == "runs"))
      assert sideloaded_run["id"] == run.id
      assert sideloaded_run["attributes"]["complete"]

      sideloaded_answer = Enum.find(included, &(&1["type"] == "answers"))
      assert sideloaded_answer["id"] == answer.id
    end

    test "creates incorrect submission", %{conn: conn, run: run, answer: answer} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "24"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => answer.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      refute submission.correct
    end
  end

  describe "create submission for food_court_frenzy" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      specification =
        Repo.insert!(%Specification{
          concept: "food_court_frenzy",
          answers: [
            %Answer{label: "burger", answer: "5.99"},
            %Answer{label: "fries", answer: "2.99"},
            %Answer{label: "soda", answer: "1.99"}
          ],
          region: region
        })

      run = Repo.insert!(%Run{specification: specification, started_at: DateTime.utc_now()})

      burger = List.first(specification.answers)

      %{run: run, specification: specification, region: region, burger: burger}
    end

    test "creates correct submission", %{conn: conn, run: run, burger: burger} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "5.99"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => burger.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      assert submission.correct
      assert submission.answer_id == burger.id

      run = Waydowntown.get_run!(run.id)
      refute run.winner_submission_id
    end

    test "creates incorrect submission", %{conn: conn, run: run, burger: burger} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "6.99"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => burger.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      refute submission.correct
    end

    test "returns 422 when submitting an unknown label", %{conn: conn, run: run} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "5.99"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => "e21cf719-ec8a-49d7-99fb-c9a356b73d95"}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Unknown answer: e21cf719-ec8a-49d7-99fb-c9a356b73d95"}]
    end

    test "returns 422 when submitting an answer for a label that already had a correct answer", %{
      conn: conn,
      run: run,
      burger: burger
    } do
      # Submit a correct answer
      conn
      |> setup_conn()
      |> post(
        Routes.submission_path(conn, :create),
        %{
          "data" => %{
            "type" => "submissions",
            "attributes" => %{"submission" => "5.99"},
            "relationships" => %{
              "run" => %{
                "data" => %{"type" => "runs", "id" => run.id}
              },
              "answer" => %{
                "data" => %{"type" => "answers", "id" => burger.id}
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
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "6.99"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                },
                "answer" => %{
                  "data" => %{"type" => "answers", "id" => burger.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Submission already exists for label: burger"}]
    end
  end
end
