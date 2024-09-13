defmodule RegistrationsWeb.SubmissionControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown
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
          duration_seconds: 300
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
          answers: [%Answer{answer: "the answer"}],
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
              "attributes" => %{"submission" => " THE ANSWER "},
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
      assert submission.submission == " THE ANSWER "

      run = Waydowntown.get_run!(run.id)
      assert run.winner_submission_id == submission.id

      assert %{
               "included" => [
                 %{
                   "type" => "specifications",
                   "id" => _specification_id,
                   "attributes" => _specification_attributes
                 },
                 %{"type" => "runs", "id" => run_id, "attributes" => %{"complete" => complete}}
               ]
             } = json_response(conn, 201)

      assert run_id == run.id
      assert complete
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

    test "fails to update an existing submission for a run", %{conn: conn, run: run} do
      # First, create an submission
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "THE ANSWER"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      # Now, try to update the submission
      conn =
        build_conn()
        |> setup_conn()
        |> patch(
          Routes.submission_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "submissions",
              "attributes" => %{"submission" => "UPDATED SUBMISSION"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Cannot update submission for run"}]
    end
  end

  describe "create submission for non-placed specification" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      specification =
        Repo.insert!(%Specification{
          concept: "orientation_memory",
          answers: [%Answer{answer: "left"}, %Answer{answer: "up"}, %Answer{answer: "right"}],
          region: region
        })

      run = Repo.insert!(%Run{specification: specification, started_at: DateTime.utc_now()})

      %{run: run, specification: specification, region: region}
    end

    test "creates and updates submission", %{conn: conn, run: run} do
      # Create initial submission
      conn =
        build_conn()
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
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      submission = Waydowntown.get_submission!(id)
      assert submission.submission == "left"
      assert submission.correct

      # Update the submission
      conn =
        build_conn()
        |> setup_conn()
        |> patch(
          Routes.submission_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "submissions",
              "attributes" => %{"submission" => "left|up"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      updated_submission = Waydowntown.get_submission!(id)
      assert updated_submission.submission == "left|up"
      assert updated_submission.correct

      # Complete the submission
      conn =
        build_conn()
        |> setup_conn()
        |> patch(
          Routes.submission_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "submissions",
              "attributes" => %{"submission" => "left|up|right"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      completed_submission = Waydowntown.get_submission!(id)
      assert completed_submission.submission == "left|up|right"
      assert completed_submission.correct

      run = Waydowntown.get_run!(run.id)
      assert run.winner_submission_id == completed_submission.id
    end

    test "always creates a new submission on POST, even if incorrect", %{conn: conn, run: run} do
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

    test "returns 422 when updating an incorrect submission", %{conn: conn, run: run} do
      # First, create an incorrect submission
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
          Routes.submission_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "submissions",
              "attributes" => %{"submission" => "ANOTHER WRONG ANSWER"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Cannot update an incorrect submission"}]
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

  describe "create submission for cardinal_memory" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      specification =
        Repo.insert!(%Specification{
          concept: "cardinal_memory",
          answers: [%Answer{answer: "north"}, %Answer{answer: "east"}, %Answer{answer: "south"}],
          region: region
        })

      run = Repo.insert!(%Run{specification: specification, started_at: DateTime.utc_now()})

      %{run: run, specification: specification, region: region}
    end

    test "creates and updates submission", %{conn: conn, run: run} do
      conn =
        build_conn()
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "north"},
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
      assert submission.submission == "north"
      assert submission.correct

      conn =
        build_conn()
        |> setup_conn()
        |> patch(
          Routes.submission_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "submissions",
              "attributes" => %{"submission" => "north|east"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      updated_submission = Waydowntown.get_submission!(id)
      assert updated_submission.submission == "north|east"
      assert updated_submission.correct

      conn =
        build_conn()
        |> setup_conn()
        |> patch(
          Routes.submission_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "submissions",
              "attributes" => %{"submission" => "north|east|south"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      completed_submission = Waydowntown.get_submission!(id)
      assert completed_submission.submission == "north|east|south"
      assert completed_submission.correct

      run = Waydowntown.get_run!(run.id)
      assert run.winner_submission_id == completed_submission.id
    end

    test "always creates a new submission on POST, even if incorrect", %{conn: conn, run: run} do
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

    test "returns 422 when updating an incorrect submission", %{conn: conn, run: run} do
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
          Routes.submission_path(conn, :update, id),
          %{
            "data" => %{
              "id" => id,
              "type" => "submissions",
              "attributes" => %{"submission" => "ANOTHER WRONG ANSWER"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Cannot update an incorrect submission"}]
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
          answers: ["42"],
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
              "attributes" => %{"submission" => "42"},
              "relationships" => %{
                "run" => %{
                  "data" => %{"type" => "runs", "id" => run.id}
                }
              }
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      answer = Waydowntown.get_answer!(id)
      assert answer.correct

      run = Waydowntown.get_run!(run.id)
      assert run.winner_submission_id == submission.id

      assert %{
               "included" => [
                 %{
                   "type" => "specifications",
                   "id" => _specification_id,
                   "attributes" => _specification_attributes
                 },
                 %{"type" => "runs", "id" => run_id, "attributes" => %{"complete" => complete}}
               ]
             } = json_response(conn, 201)

      assert run_id == run.id
      assert complete
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
              "attributes" => %{"submission" => "24"},
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

    test "returns 422 when submitting an unknown label", %{conn: conn, run: run, burger: burger} do
      conn =
        conn
        |> setup_conn()
        |> post(
          Routes.submission_path(conn, :create),
          %{
            "data" => %{
              "type" => "submissions",
              "attributes" => %{"submission" => "unknown|5.99"},
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

      assert json_response(conn, 422)["errors"] == %{"detail" => ["Unknown label: e21cf719-ec8a-49d7-99fb-c9a356b73d95"]}
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
            "attributes" => %{"submission" => "burger|5.99"},
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

      assert json_response(conn, 422)["errors"] == %{"detail" => ["Answer already submitted for label: burger"]}
    end
  end
end
