defmodule RegistrationsWeb.Api.DeviceTokensTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Landgrab.DeviceToken
  alias Registrations.Repo

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

  describe "POST /powapi/device-tokens" do
    setup ctx do
      user = insert(:user, email: unique_email("push"))
      %{conn: authed_conn(ctx, user), user: user}
    end

    test "registers a token for the current user", %{conn: conn, user: user} do
      body =
        conn
        |> post("/powapi/device-tokens", %{"token" => "fcm-abc", "platform" => "ios"})
        |> json_response(200)

      assert body["ok"]

      device_token = Repo.get_by!(DeviceToken, token: "fcm-abc")
      assert device_token.user_id == user.id
      assert device_token.platform == "ios"
    end

    test "re-registering an existing token moves it to the new user", %{conn: conn, user: user} do
      other = insert(:user, email: unique_email("other"))
      {:ok, _} = Registrations.Landgrab.register_device_token(other.id, "fcm-shared", "android")

      conn
      |> post("/powapi/device-tokens", %{"token" => "fcm-shared", "platform" => "android"})
      |> json_response(200)

      assert [device_token] = Repo.all(Ecto.Query.where(DeviceToken, token: "fcm-shared"))
      assert device_token.user_id == user.id
    end

    test "rejects an unknown platform", %{conn: conn} do
      body =
        conn
        |> post("/powapi/device-tokens", %{"token" => "fcm-def", "platform" => "blackberry"})
        |> json_response(422)

      assert body["errors"]["platform"]
    end

    test "rejects a missing token", %{conn: conn} do
      conn
      |> post("/powapi/device-tokens", %{"platform" => "ios"})
      |> json_response(400)
    end
  end

  test "rejects unauthenticated requests", %{conn: conn} do
    conn
    |> put_req_header("accept", "application/json")
    |> post("/powapi/device-tokens", %{"token" => "fcm-anon", "platform" => "ios"})
    |> json_response(401)
  end
end
