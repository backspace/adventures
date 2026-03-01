defmodule RegistrationsWeb.AnswerControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Specification

  setup %{conn: conn} do
    user = insert(:octavia)
    other_user = insert(:user)

    my_specification =
      Repo.insert!(%Specification{
        creator_id: user.id,
        concept: "string_collector"
      })

    other_specification =
      Repo.insert!(%Specification{
        creator_id: other_user.id,
        concept: "string_collector"
      })

    my_answer =
      Repo.insert!(%Answer{
        answer: "existing answer",
        label: "existing label",
        hint: "existing hint",
        order: 1,
        specification_id: my_specification.id
      })

    other_answer =
      Repo.insert!(%Answer{
        answer: "other answer",
        order: 1,
        specification_id: other_specification.id
      })

    authed_conn = build_conn()

    authed_conn =
      post(authed_conn, Routes.api_session_path(authed_conn, :create), %{
        "user" => %{"email" => user.email, "password" => "Xenogenesis"}
      })

    json = json_response(authed_conn, 200)
    authorization_token = json["data"]["access_token"]

    {:ok,
     conn:
       conn
       |> put_req_header("accept", "application/vnd.api+json")
       |> put_req_header("content-type", "application/vnd.api+json"),
     authorization_token: authorization_token,
     my_specification: my_specification,
     other_specification: other_specification,
     my_answer: my_answer,
     other_answer: other_answer,
     user: user}
  end

  describe "create answer" do
    test "creates answer for own specification", %{
      conn: conn,
      authorization_token: authorization_token,
      my_specification: my_specification
    } do
      conn =
        conn
        |> put_req_header("authorization", "#{authorization_token}")
        |> post(Routes.answer_path(conn, :create), %{
          "data" => %{
            "type" => "answers",
            "attributes" => %{
              "answer" => "new answer",
              "label" => "new label",
              "hint" => "new hint"
            },
            "relationships" => %{
              "specification" => %{
                "data" => %{"type" => "specifications", "id" => my_specification.id}
              }
            }
          }
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["type"] == "answers"
      assert data["attributes"]["answer"] == "new answer"
      assert data["attributes"]["label"] == "new label"
      assert data["attributes"]["hint"] == "new hint"
      assert data["attributes"]["order"] == 2
    end

    test "auto-assigns order starting at 1 for empty specification", %{
      conn: conn,
      authorization_token: authorization_token
    } do
      empty_specification =
        Repo.insert!(%Specification{
          creator_id: Repo.get_by!(RegistrationsWeb.User, email: "octavia.butler@example.com").id,
          concept: "string_collector"
        })

      conn =
        conn
        |> put_req_header("authorization", "#{authorization_token}")
        |> post(Routes.answer_path(conn, :create), %{
          "data" => %{
            "type" => "answers",
            "attributes" => %{
              "answer" => "first answer"
            },
            "relationships" => %{
              "specification" => %{
                "data" => %{"type" => "specifications", "id" => empty_specification.id}
              }
            }
          }
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["attributes"]["order"] == 1
    end

    test "returns 401 when creating answer for other user's specification", %{
      conn: conn,
      authorization_token: authorization_token,
      other_specification: other_specification
    } do
      conn =
        conn
        |> put_req_header("authorization", "#{authorization_token}")
        |> post(Routes.answer_path(conn, :create), %{
          "data" => %{
            "type" => "answers",
            "attributes" => %{
              "answer" => "unauthorized answer"
            },
            "relationships" => %{
              "specification" => %{
                "data" => %{"type" => "specifications", "id" => other_specification.id}
              }
            }
          }
        })

      assert json_response(conn, 401)["errors"] == [%{"detail" => "Unauthorized"}]
    end

    test "returns 422 when missing required fields", %{
      conn: conn,
      authorization_token: authorization_token,
      my_specification: my_specification
    } do
      conn =
        conn
        |> put_req_header("authorization", "#{authorization_token}")
        |> post(Routes.answer_path(conn, :create), %{
          "data" => %{
            "type" => "answers",
            "attributes" => %{},
            "relationships" => %{
              "specification" => %{
                "data" => %{"type" => "specifications", "id" => my_specification.id}
              }
            }
          }
        })

      assert json_response(conn, 422)
    end
  end

  describe "update answer" do
    test "updates own answer", %{
      conn: conn,
      authorization_token: authorization_token,
      my_answer: my_answer
    } do
      conn =
        conn
        |> put_req_header("authorization", "#{authorization_token}")
        |> patch(Routes.answer_path(conn, :update, my_answer), %{
          "data" => %{
            "type" => "answers",
            "id" => my_answer.id,
            "attributes" => %{
              "answer" => "updated answer",
              "label" => "updated label",
              "hint" => "updated hint"
            }
          }
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["answer"] == "updated answer"
      assert data["attributes"]["label"] == "updated label"
      assert data["attributes"]["hint"] == "updated hint"
    end

    test "returns 401 when updating other user's answer", %{
      conn: conn,
      authorization_token: authorization_token,
      other_answer: other_answer
    } do
      conn =
        conn
        |> put_req_header("authorization", "#{authorization_token}")
        |> patch(Routes.answer_path(conn, :update, other_answer), %{
          "data" => %{
            "type" => "answers",
            "id" => other_answer.id,
            "attributes" => %{
              "answer" => "unauthorized update"
            }
          }
        })

      assert json_response(conn, 401)["errors"] == [%{"detail" => "Unauthorized"}]
    end
  end

  describe "delete answer" do
    test "deletes own answer", %{
      conn: conn,
      authorization_token: authorization_token,
      my_answer: my_answer
    } do
      conn =
        conn
        |> put_req_header("authorization", "#{authorization_token}")
        |> delete(Routes.answer_path(conn, :delete, my_answer))

      assert response(conn, 204)
      assert_raise Ecto.NoResultsError, fn -> Repo.get!(Answer, my_answer.id) end
    end

    test "returns 401 when deleting other user's answer", %{
      conn: conn,
      authorization_token: authorization_token,
      other_answer: other_answer
    } do
      conn =
        conn
        |> put_req_header("authorization", "#{authorization_token}")
        |> delete(Routes.answer_path(conn, :delete, other_answer))

      assert json_response(conn, 401)["errors"] == [%{"detail" => "Unauthorized"}]
      assert Repo.get!(Answer, other_answer.id)
    end
  end
end
