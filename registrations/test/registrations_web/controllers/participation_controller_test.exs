defmodule RegistrationsWeb.ParticipationControllerTest do
  use RegistrationsWeb.ConnCase

  import Phoenix.ChannelTest

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Specification

  describe "create participation" do
    setup [:setup_conn, :create_run]

    test "renders new participation", %{conn: conn, run: run} do
      user =
        insert(:octavia, admin: true)

      conn =
        conn
        |> put_req_header("authorization", "#{setup_user_and_get_token(user)}")
        |> post(Routes.participation_path(conn, :create), %{
          "data" => %{
            "type" => "participations",
            "relationships" => %{
              "run" => %{
                "data" => %{
                  "type" => "run",
                  "id" => run.id
                }
              }
            }
          }
        })

      assert %{
               "id" => _id,
               "type" => "participations",
               "relationships" => relationships,
               "attributes" => _attributes,
               "links" => _links
             } = json_response(conn, 201)["data"]

      run_relationship = relationships["run"]
      user_relationship = relationships["user"]

      assert run_relationship["data"]["id"] == run.id
      assert user_relationship["data"]["id"] == user.id
    end

    test "errors when user is already a participant", %{conn: conn, run: run, user: user} do
      conn =
        conn
        |> put_req_header("authorization", "#{setup_user_and_get_token(user)}")
        |> post(Routes.participation_path(conn, :create), %{
          "data" => %{
            "type" => "participation",
            "relationships" => %{
              "run" => %{
                "data" => %{
                  "type" => "run",
                  "id" => run.id
                }
              }
            }
          }
        })

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update participation with readiness" do
    setup do
      user1 = insert(:user)
      user2 = insert(:user)
      specification = Repo.insert!(%Specification{concept: "bluetooth_collector"})
      {:ok, run} = Waydowntown.create_run(user1, %{}, %{"concept" => specification.concept})
      [participation1] = run.participations
      {:ok, participation2} = Waydowntown.join_run(user2, run.id)

      {:ok, _, socket1} =
        RegistrationsWeb.UserSocket
        |> socket("user_id", %{user_id: user1.id})
        |> subscribe_and_join(RegistrationsWeb.RunChannel, "run:#{run.id}")

      {:ok, _, socket2} =
        RegistrationsWeb.UserSocket
        |> socket("user_id", %{user_id: user2.id})
        |> subscribe_and_join(RegistrationsWeb.RunChannel, "run:#{run.id}")

      %{
        run: run,
        user1: user1,
        user2: user2,
        participation1: participation1,
        participation2: participation2,
        socket1: socket1,
        socket2: socket2
      }
    end

    test "broadcasts are pushed to the client", %{
      conn: conn,
      run: run,
      participation1: participation1,
      participation2: participation2,
      user1: user1,
      user2: user2,
      socket1: socket1,
      socket2: socket2
    } do
      conn =
        %{conn: conn}
        |> setup_conn()
        |> Map.get(:conn)
        |> put_req_header("authorization", setup_user_and_get_token(user1))
        |> put(Routes.participation_path(conn, :update, participation1.id), %{
          "data" => %{
            "type" => "participations",
            "id" => participation1.id,
            "attributes" => %{
              "ready" => true
            }
          }
        })

      %{"id" => participation1_id, "attributes" => %{"ready_at" => ready_at}} = json_response(conn, 200)["data"]

      assert ready_at
      assert_push "participation_update", %{participation_id: participation1_id, ready: true}

      conn = build_conn()

      conn =
        %{conn: conn}
        |> setup_conn()
        |> Map.get(:conn)
        |> put_req_header("authorization", setup_user_and_get_token(user2))
        |> put(Routes.participation_path(conn, :update, participation2.id), %{
          "data" => %{
            "type" => "participations",
            "id" => participation2.id,
            "attributes" => %{
              "ready" => true
            }
          }
        })

      assert json_response(conn, 200)["data"]["attributes"]["ready_at"] != nil
      # assert_push "participation_update", %{participation_id: participation2.id, ready: true}
      # assert_push "run_started", %{run_id: run.id, start_time: start_time}

      # Verify that the run's started_at is set
      updated_run = Waydowntown.get_run!(run.id)
      assert updated_run.started_at
    end
  end

  defp setup_conn(%{conn: conn}) do
    conn =
      conn
      |> put_req_header("accept", "application/vnd.api+json")
      |> put_req_header("content-type", "application/vnd.api+json")

    %{conn: conn}
  end

  defp create_run(_) do
    user = insert(:user)
    specification = Repo.insert!(%Specification{concept: "bluetooth_collector"})
    {:ok, run} = Waydowntown.create_run(user, %{}, %{"concept" => specification.concept})
    %{run: run, user: user}
  end

  defp setup_user_and_get_token(user) do
    authed_conn = build_conn()

    authed_conn =
      post(authed_conn, Routes.api_session_path(authed_conn, :create), %{
        "user" => %{"email" => user.email, "password" => "Xenogenesis"}
      })

    json = json_response(authed_conn, 200)

    json["data"]["access_token"]
  end
end
