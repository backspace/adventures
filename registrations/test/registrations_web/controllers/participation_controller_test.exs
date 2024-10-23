defmodule RegistrationsWeb.ParticipationControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Specification

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/vnd.api+json")}
    {:ok, conn: put_req_header(conn, "content-type", "application/vnd.api+json")}
  end

  describe "create participation" do
    setup [:create_run]

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
