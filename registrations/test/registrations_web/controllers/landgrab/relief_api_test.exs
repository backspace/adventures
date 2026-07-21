defmodule RegistrationsWeb.Landgrab.ReliefApiTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Accounts

  defp authed_conn(%{conn: conn}, %{} = user) do
    auth_conn =
      post(build_conn(), Routes.api_session_path(build_conn(), :create), %{
        "user" => %{"email" => user.email, "password" => "Xenogenesis"}
      })

    token = json_response(auth_conn, 200)["data"]["access_token"]

    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", token)
  end

  defp unique_email(prefix), do: "#{prefix}#{System.unique_integer([:positive])}@example.com"

  describe "as a supervisor" do
    setup ctx do
      supervisor = insert(:user, email: unique_email("super"))
      Accounts.assign_role(supervisor.id, "validation_supervisor")
      %{conn: authed_conn(ctx, supervisor)}
    end

    test "toggles relief on and off", %{conn: conn} do
      assert %{"active" => false} =
               conn |> get("/landgrab/supervision/relief") |> json_response(200)

      assert %{"active" => true} =
               conn
               |> put("/landgrab/supervision/relief", %{"on" => true})
               |> json_response(200)

      assert %{"active" => true} =
               conn |> get("/landgrab/supervision/relief") |> json_response(200)

      assert %{"active" => false} =
               conn
               |> put("/landgrab/supervision/relief", %{"on" => false})
               |> json_response(200)
    end
  end

  test "non-supervisors are forbidden", ctx do
    player = insert(:user, email: unique_email("player"))
    conn = authed_conn(ctx, player)

    conn |> get("/landgrab/supervision/relief") |> json_response(403)
    conn |> put("/landgrab/supervision/relief", %{"on" => true}) |> json_response(403)
  end
end
