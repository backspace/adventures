defmodule RegistrationsWeb.Landgrab.RegionsControllerTest do
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

  describe "GET /landgrab/regions" do
    setup ctx do
      user = insert(:user, email: "author#{System.unique_integer([:positive])}@example.com")
      Accounts.assign_role(user.id, "author")
      %{conn: authed_conn(ctx, user), user: user}
    end

    test "list rows include the ancestor chain so the parent shows on return",
         %{conn: conn} do
      parent = insert(:poles_region, name: "777 Main St")
      child = insert(:poles_region, name: "4th floor", parent_region: parent)

      body = conn |> get("/landgrab/regions") |> json_response(200)

      returned = Enum.find(body["regions"], &(&1["id"] == child.id))
      assert returned["parent_region_id"] == parent.id
      assert returned["ancestors"] == [%{"id" => parent.id, "name" => "777 Main St"}]

      root = Enum.find(body["regions"], &(&1["id"] == parent.id))
      assert root["ancestors"] == []
    end
  end
end
