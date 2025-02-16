defmodule RegistrationsWeb.ApiUserControllerTest do
  use RegistrationsWeb.ConnCase

  setup %{conn: conn} do
    user = insert(:octavia, admin: true)

    auth_conn = build_conn()

    auth_conn =
      post(auth_conn, Routes.api_session_path(auth_conn, :create), %{
        "user" => %{"email" => user.email, "password" => "Xenogenesis"}
      })

    json = json_response(auth_conn, 200)
    authorization_token = json["data"]["access_token"]

    %{
      user: user,
      authorization_token: authorization_token,
      conn:
        conn
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("content-type", "application/vnd.api+json")
    }
  end

  test "updates the user name", %{conn: conn, authorization_token: authorization_token, user: user} do
    conn =
      conn
      |> put_req_header("authorization", "#{authorization_token}")
      |> post(Routes.api_user_path(conn, :update), %{
        "data" => %{
          "type" => "users",
          "id" => user.id,
          "attributes" => %{
            "name" => "Octavia"
          }
        }
      })

    assert json_response(conn, 200)["data"]["id"] == user.id
    assert json_response(conn, 200)["data"]["attributes"]["admin"]
    assert json_response(conn, 200)["data"]["attributes"]["email"] == user.email
    assert json_response(conn, 200)["data"]["attributes"]["name"] == "Octavia"
  end

  test "returns error with invalid attributes", %{
    conn: conn,
    authorization_token: authorization_token,
    user: user
  } do
    conn =
      conn
      |> put_req_header("authorization", "#{authorization_token}")
      |> post(Routes.api_user_path(conn, :update), %{
        "data" => %{
          "type" => "users",
          "id" => user.id,
          "attributes" => %{}
        }
      })

    assert json_response(conn, 422)["errors"] == [
             %{"source" => %{"pointer" => "/data/attributes/name"}, "detail" => "can't be blank"}
           ]
  end
end
