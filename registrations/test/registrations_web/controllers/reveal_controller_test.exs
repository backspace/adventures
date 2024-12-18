defmodule RegistrationsWeb.RevealControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Answer

  setup %{conn: conn} do
    user = insert(:user)
    answer = Repo.insert!(%Answer{hint: "This is a hint"})
    answer_without_hint = Repo.insert!(%Answer{hint: nil})

    conn = setup_conn(conn, user)

    %{conn: conn, user: user, answer: answer, answer_without_hint: answer_without_hint}
  end

  describe "create reveal" do
    test "creates reveal and returns hint for a provided answer", %{
      conn: conn,
      answer: answer
    } do
      conn =
        post(conn, Routes.reveal_path(conn, :create), %{
          "data" => %{
            "type" => "reveals",
            "relationships" => %{
              "answer" => %{
                "data" => %{"type" => "answers", "id" => answer.id}
              }
            }
          }
        })

      assert %{"included" => included} = json_response(conn, 201)
      sideloaded_answer = Enum.find(included, &(&1["type"] == "answers"))
      assert sideloaded_answer["attributes"]["hint"] == "This is a hint"
    end

    test "creates reveal and returns hint with a random answer", %{conn: conn} do
      conn =
        post(conn, Routes.reveal_path(conn, :create), %{
          "data" => %{
            "type" => "reveals"
          }
        })

      assert %{"included" => included} = json_response(conn, 201)
      sideloaded_answer = Enum.find(included, &(&1["type"] == "answers"))
      assert sideloaded_answer["attributes"]["hint"] != nil
    end

    test "returns error when answer is already revealed", %{
      conn: conn,
      user: user,
      answer: answer
    } do
      {:ok, _reveal} = Waydowntown.create_reveal(user, answer.id)

      conn =
        post(conn, Routes.reveal_path(conn, :create), %{
          "data" => %{
            "type" => "reveals",
            "relationships" => %{
              "answer" => %{
                "data" => %{"type" => "answers", "id" => answer.id}
              }
            }
          }
        })

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Answer already revealed"}]
    end

    test "returns error when answer has no hint", %{
      conn: conn,
      answer_without_hint: answer
    } do
      conn =
        post(conn, Routes.reveal_path(conn, :create), %{
          "data" => %{
            "type" => "reveals",
            "relationships" => %{
              "answer" => %{
                "data" => %{"type" => "answers", "id" => answer.id}
              }
            }
          }
        })

      assert json_response(conn, 422)["errors"] == [%{"detail" => "Hint not available for this answer"}]
    end

    test "returns error when no reveals are available", %{conn: conn, user: user, answer: answer} do
      {:ok, _reveal} = Waydowntown.create_reveal(user, answer.id)

      conn =
        post(conn, Routes.reveal_path(conn, :create), %{
          "data" => %{
            "type" => "reveals"
          }
        })

      assert json_response(conn, 422)["errors"] == [%{"detail" => "No reveals available"}]
    end
  end

  defp setup_conn(conn, user) do
    conn
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("authorization", setup_user_and_get_token(user))
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
