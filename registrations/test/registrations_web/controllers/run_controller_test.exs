defmodule RegistrationsWeb.RunControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Region
  alias Registrations.Waydowntown.Specification
  alias Registrations.Waydowntown.Submission

  setup %{conn: conn} do
    {:ok,
     conn:
       conn
       |> put_req_header("accept", "application/vnd.api+json")
       |> put_req_header("content-type", "application/vnd.api+json")
       |> put_req_header("authorization", setup_user_and_get_token())}
  end

  describe "show run" do
    setup do
      user = Registrations.Repo.get_by(RegistrationsWeb.User, email: "octavia.butler@example.com") || insert(:octavia)

      parent_region =
        Repo.insert!(%Region{name: "Parent Region", geom: %Geo.Point{coordinates: {-97.0, 40.1}, srid: 4326}})

      child_region =
        Repo.insert!(%Region{
          name: "Child Region",
          parent_id: parent_region.id,
          geom: %Geo.Point{coordinates: {-97.143130, 49.891725}, srid: 4326}
        })

      specification =
        Repo.insert!(%Specification{
          concept: "fill_in_the_blank",
          task_description: "This is a ____",
          region_id: child_region.id,
          start_description: "Outside the coat check",
          duration: 300
        })

      {:ok, run} = Waydowntown.create_run(user, %{}, %{"concept" => specification.concept})

      submission =
        Repo.insert!(%Submission{
          submission: "incorrect",
          correct: false,
          run_id: run.id
        })

      answer_1 =
        Repo.insert!(%Answer{
          label: "answer_1",
          hint: "hint_1",
          specification: specification
        })

      answer_2 =
        Repo.insert!(%Answer{
          label: "answer_2",
          hint: "hint_2",
          specification: specification
        })

      %{
        user: user,
        run: run,
        specification: specification,
        submission: submission,
        child_region: child_region,
        parent_region: parent_region,
        answers: [answer_1, answer_2]
      }
    end

    test "returns run with nested specification, regions, submissions, and progress attributes, but no task description before the run has started",
         %{
           conn: conn,
           run: run,
           specification: specification,
           submission: submission,
           child_region: child_region,
           parent_region: parent_region
         } do
      conn = get(conn, Routes.run_path(conn, :show, run.id))

      assert %{
               "data" => %{
                 "id" => run_id,
                 "type" => "runs",
                 "attributes" => %{
                   "complete" => false
                 },
                 "relationships" => %{
                   "specification" => %{
                     "data" => %{"id" => specification_id, "type" => "specifications"}
                   }
                 }
               },
               "included" => included
             } = json_response(conn, 200)

      assert run_id == run.id
      assert specification_id == specification.id

      included_specification = Enum.find(included, &(&1["type"] == "specifications"))

      assert included_specification["id"] == specification.id
      assert included_specification["attributes"]["concept"] == "fill_in_the_blank"
      assert included_specification["attributes"]["start_description"] == "Outside the coat check"
      assert included_specification["attributes"]["duration"] == 300
      assert included_specification["relationships"]["region"]["data"]["id"] == child_region.id
      refute included_specification["attributes"]["task_description"]

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

      included_submission = Enum.find(included, &(&1["type"] == "submissions"))

      assert included_submission["id"] == submission.id
      assert included_submission["attributes"]["submission"] == "incorrect"
      refute included_submission["attributes"]["correct"]
    end

    test "task description is included in the run when the it has started",
         %{
           user: user,
           conn: conn,
           run: run
         } do
      Waydowntown.start_run(user, run)
      conn = get(conn, Routes.run_path(conn, :show, run.id))

      assert %{
               "data" => %{
                 "id" => _run_id,
                 "type" => "runs",
                 "attributes" => %{
                   "complete" => false,
                   "task_description" => "This is a ____"
                 },
                 "relationships" => %{
                   "specification" => %{
                     "data" => %{"id" => _specification_id, "type" => "specifications"}
                   }
                 }
               },
               "included" => included
             } = json_response(conn, 200)

      included_specification = Enum.find(included, &(&1["type"] == "specifications"))
      refute included_specification["attributes"]["task_description"] == "This is a ____"
    end

    test "answer hint is included when revealed for this user", %{
      user: user,
      conn: conn,
      run: run,
      answers: [answer | _]
    } do
      {:ok, _reveal} = Waydowntown.create_reveal(user, answer.id)

      conn = get(conn, Routes.run_path(conn, :show, run.id))

      included = json_response(conn, 200)["included"]
      revealed_answer = Enum.find(included, &(&1["type"] == "answers" && &1["id"] == answer.id))

      assert revealed_answer["attributes"]["hint"] == answer.hint
    end

    test "answer hint is null when not revealed for this user", %{
      conn: conn,
      run: run,
      answers: [answer | _]
    } do
      another_user = insert(:user)
      {:ok, _reveal} = Waydowntown.create_reveal(another_user, answer.id)

      conn = get(conn, Routes.run_path(conn, :show, run.id))

      included = json_response(conn, 200)["included"]
      unrevealed_answer = Enum.find(included, &(&1["type"] == "answers" && &1["id"] == answer.id))

      refute unrevealed_answer["attributes"]["hint"]
    end
  end

  describe "create run" do
    setup do
      region = Repo.insert!(%Region{name: "Test Region"})

      specification =
        Repo.insert!(%Specification{
          concept: "fill_in_the_blank",
          task_description: "This is a ____",
          region: region
        })

      %{specification: specification, region: region}
    end

    test "creates run", %{conn: conn, specification: specification} do
      conn =
        post(
          conn,
          Routes.run_path(conn, :create),
          %{
            "data" => %{
              "type" => "runs",
              "attributes" => %{}
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert %{"included" => included} = json_response(conn, 201)

      sideloaded_specification = Enum.find(included, &(&1["type"] == "specifications"))
      assert sideloaded_specification["id"] == specification.id

      run = id |> Waydowntown.get_run!() |> Repo.preload(:participations)
      assert run.specification_id == specification.id

      user = Registrations.Repo.get_by(RegistrationsWeb.User, email: "octavia.butler@example.com")

      assert length(run.participations) == 1
      assert run.participations |> hd() |> Map.get(:user_id) == user.id
    end

    test "creates run with filtered specification", %{conn: conn} do
      bluetooth_specification =
        Repo.insert!(%Specification{
          concept: "bluetooth_collector",
          region_id: Repo.insert!(%Region{}).id
        })

      conn =
        post(
          conn,
          Routes.run_path(conn, :create) <> "?filter[specification.concept]=bluetooth_collector",
          %{
            "data" => %{
              "type" => "runs",
              "attributes" => %{}
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert %{"included" => included} = json_response(conn, 201)

      sideloaded_specification = Enum.find(included, &(&1["type"] == "specifications"))
      assert sideloaded_specification["attributes"]["concept"] == "bluetooth_collector"

      run = Waydowntown.get_run!(id)
      assert run.specification_id == bluetooth_specification.id
    end

    test "creates run with non-placed specification, blank answers are included", %{
      conn: conn
    } do
      conn =
        post(
          conn,
          Routes.run_path(conn, :create) <> "?filter[specification.placed]=false",
          %{
            "data" => %{
              "type" => "runs",
              "attributes" => %{}
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert %{"included" => included} = json_response(conn, 201)

      sideloaded_specification = Enum.find(included, &(&1["type"] == "specifications"))
      assert sideloaded_specification["attributes"]["concept"] in ["orientation_memory", "cardinal_memory"]

      specification = Specification |> Repo.get!(sideloaded_specification["id"]) |> Repo.preload(:answers)

      sideloaded_answers = Enum.filter(included, &(&1["type"] == "answers"))
      assert length(sideloaded_answers) > 0
      assert length(sideloaded_answers) == length(specification.answers)

      Enum.each(specification.answers, fn answer ->
        sideloaded_answer = Enum.find(sideloaded_answers, &(&1["id"] == answer.id))
        assert sideloaded_answer["attributes"]["order"] == answer.order
      end)

      run = Waydowntown.get_run!(id)
      specification = Waydowntown.get_specification!(run.specification_id)
      assert specification.concept in ["orientation_memory", "cardinal_memory"]
    end

    test "creates new specification for unplaced concept even if one exists, blank answers are included", %{conn: conn} do
      existing_specification =
        Repo.insert!(%Specification{
          concept: "orientation_memory",
          task_description: "Existing description",
          region_id: Repo.insert!(%Region{}).id
        })

      conn =
        post(
          conn,
          Routes.run_path(conn, :create) <> "?filter[specification.concept]=orientation_memory",
          %{
            "data" => %{
              "type" => "runs",
              "attributes" => %{}
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert %{"included" => included} = json_response(conn, 201)

      sideloaded_specification = Enum.find(included, &(&1["type"] == "specifications"))
      assert sideloaded_specification["attributes"]["concept"] == "orientation_memory"
      assert sideloaded_specification["id"] != existing_specification.id

      specification = Specification |> Repo.get!(sideloaded_specification["id"]) |> Repo.preload(:answers)

      sideloaded_answers = Enum.filter(included, &(&1["type"] == "answers"))
      assert length(sideloaded_answers) > 0
      assert length(sideloaded_answers) == length(specification.answers)

      run = Waydowntown.get_run!(id)
      new_specification = Waydowntown.get_specification!(run.specification_id)
      assert new_specification.id != existing_specification.id
      assert new_specification.concept == "orientation_memory"
    end

    test "creates run with specific specification id", %{conn: conn, specification: specification} do
      conn =
        post(
          conn,
          Routes.run_path(conn, :create) <> "?filter[specification.id]=#{specification.id}",
          %{
            "data" => %{
              "type" => "runs",
              "attributes" => %{}
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert %{"included" => included} = json_response(conn, 201)

      sideloaded_specification = Enum.find(included, &(&1["type"] == "specifications"))
      assert sideloaded_specification["id"] == specification.id

      run = Waydowntown.get_run!(id)
      assert run.specification_id == specification.id
    end

    test "returns 422 when specification id does not exist", %{conn: conn} do
      non_existent_specification_id = "0de26579-1f4f-48cb-9ad5-9ed1a72f4878"

      conn =
        post(
          conn,
          Routes.run_path(conn, :create) <> "?filter[specification.id]=#{non_existent_specification_id}",
          %{
            "data" => %{
              "type" => "runs",
              "attributes" => %{}
            }
          }
        )

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "creates run with nearest specification", %{conn: conn} do
      closer_region = Repo.insert!(%Region{name: "Region 1", geom: %Geo.Point{coordinates: {-96.1, 48.1}, srid: 4326}})
      farther_region = Repo.insert!(%Region{name: "Region 2", geom: %Geo.Point{coordinates: {-96.2, 48.2}, srid: 4326}})

      reversed_lat_lon_region =
        Repo.insert!(%Region{name: "Region 3", geom: %Geo.Point{coordinates: {48.2, -96.2}, srid: 4326}})

      closer_specification =
        Repo.insert!(%Specification{
          concept: "fill_in_the_blank",
          task_description: "This is a ____",
          region: closer_region
        })

      Repo.insert!(%Specification{
        concept: "bluetooth_collector",
        region: farther_region
      })

      Repo.insert!(%Specification{
        concept: "bluetooth_collector",
        region: reversed_lat_lon_region
      })

      conn =
        post(
          conn,
          Routes.run_path(conn, :create) <> "?filter[specification.position]=48.0,-96.0",
          %{
            "data" => %{
              "type" => "runs",
              "attributes" => %{}
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert %{"included" => included} = json_response(conn, 201)

      sideloaded_specification = Enum.find(included, &(&1["type"] == "specifications"))
      assert sideloaded_specification["id"] == closer_specification.id

      sideloaded_region = Enum.find(included, &(&1["type"] == "regions"))
      assert sideloaded_region["id"] == closer_region.id
      assert sideloaded_region["attributes"]["latitude"] == "48.1"
      assert sideloaded_region["attributes"]["longitude"] == "-96.1"

      run = Waydowntown.get_run!(id)
      assert run.specification_id == closer_specification.id
    end

    test "creates run with food_court_frenzy concept", %{conn: conn} do
      Repo.insert!(%Specification{
        concept: "food_court_frenzy",
        answers: [
          %Answer{label: "Burger", answer: "6.99"},
          %Answer{label: "Pizza", answer: "7.99"},
          %Answer{label: "Salad", answer: "5.99"},
          %Answer{label: "Soda", answer: "3.99"}
        ],
        region: Repo.insert!(%Region{})
      })

      conn =
        post(
          conn,
          Routes.run_path(conn, :create) <> "?filter[specification.concept]=food_court_frenzy",
          %{
            "data" => %{
              "type" => "runs",
              "attributes" => %{}
            }
          }
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
      assert %{"included" => included} = json_response(conn, 201)

      sideloaded_specification = Enum.find(included, &(&1["type"] == "specifications"))
      assert sideloaded_specification["attributes"]["concept"] == "food_court_frenzy"

      sideloaded_answers = sideloaded_specification["relationships"]["answers"]["data"]
      assert Enum.count(sideloaded_answers) == 4

      answer_data =
        included
        |> Enum.map(fn item ->
          if item["type"] == "answers", do: item["attributes"]
        end)
        |> Enum.reject(&is_nil/1)

      assert Enum.all?(answer_data, fn answer ->
               answer["label"] in ["Burger", "Pizza", "Salad", "Soda"] and
                 is_nil(answer["answer"])
             end)

      run = Waydowntown.get_run!(id)
      specification = Waydowntown.get_specification!(run.specification_id)
      assert specification.concept == "food_court_frenzy"
    end
  end

  describe "start run" do
    setup do
      user = Registrations.Repo.get_by(RegistrationsWeb.User, email: "octavia.butler@example.com") || insert(:octavia)

      specification =
        Repo.insert!(%Specification{concept: "fill_in_the_blank", answers: [%Answer{answer: "answer"}], duration: 300})

      {:ok, run} = Waydowntown.create_run(user, %{}, %{"concept" => specification.concept})
      %{user: user, run: run}
    end

    test "starts the run", %{conn: conn, run: run} do
      conn = post(conn, Routes.run_start_path(conn, :start, run), %{"data" => %{"type" => "runs", "id" => run.id}})
      assert %{"data" => %{"id" => _id, "attributes" => %{"started_at" => started_at}}} = json_response(conn, 200)
      assert started_at != nil
    end

    test "returns error when starting an already started run", %{user: user, conn: conn, run: run} do
      Waydowntown.start_run(user, run)
      conn = post(conn, Routes.run_start_path(conn, :start, run), %{"data" => %{"type" => "runs", "id" => run.id}})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "start another user's run" do
    setup do
      Repo.insert!(%Specification{concept: "fill_in_the_blank"})

      user = insert(:user)
      {:ok, run} = Waydowntown.create_run(user, %{}, %{"concept" => "fill_in_the_blank"})
      %{run: run}
    end

    test "returns error", %{conn: conn, run: run} do
      conn = post(conn, Routes.run_start_path(conn, :start, run), %{"data" => %{"type" => "runs", "id" => run.id}})
      assert json_response(conn, 422)["errors"] == [%{"detail" => "User is not a participant in this run"}]
    end
  end

  describe "index" do
    setup do
      user = Registrations.Repo.get_by(RegistrationsWeb.User, email: "octavia.butler@example.com") || insert(:octavia)
      specification = Repo.insert!(%Specification{concept: "fill_in_the_blank"})

      {:ok, started_run} = Waydowntown.create_run(user, %{}, %{"concept" => specification.concept})
      {:ok, _} = Waydowntown.start_run(user, started_run)

      {:ok, not_started_run} = Waydowntown.create_run(user, %{}, %{"concept" => specification.concept})

      %{user: user, started_run: started_run, not_started_run: not_started_run}
    end

    test "lists all started runs when filter[started]=true", %{conn: conn, started_run: started_run} do
      conn = get(conn, Routes.run_path(conn, :index, filter: %{started: "true"}))
      response = json_response(conn, 200)

      assert length(response["data"]) == 1
      assert Enum.at(response["data"], 0)["id"] == started_run.id
    end

    test "lists all not started runs when filter[started]=false", %{conn: conn, not_started_run: not_started_run} do
      conn = get(conn, Routes.run_path(conn, :index, filter: %{started: "false"}))
      response = json_response(conn, 200)

      assert length(response["data"]) == 1
      assert Enum.at(response["data"], 0)["id"] == not_started_run.id
    end

    test "lists all runs when no started filter is provided", %{conn: conn} do
      conn = get(conn, Routes.run_path(conn, :index))
      response = json_response(conn, 200)

      assert length(response["data"]) == 2
    end
  end

  defp setup_user_and_get_token do
    user =
      Registrations.Repo.get_by(RegistrationsWeb.User, email: "octavia.butler@example.com") ||
        insert(:octavia, admin: true)

    authed_conn = build_conn()

    authed_conn =
      post(authed_conn, Routes.api_session_path(authed_conn, :create), %{
        "user" => %{"email" => user.email, "password" => "Xenogenesis"}
      })

    json = json_response(authed_conn, 200)

    json["data"]["access_token"]
  end
end
