defmodule RegistrationsWeb.Api.ResetPasswordTest do
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  # The mailer's subject line goes through `phrase/1`, which reads the
  # configured adventure — set it so the reset email can be built.
  use Registrations.SetAdventure, adventure: "landgrab"

  alias Registrations.SwooshHelper

  defp unique_email(prefix), do: "#{prefix}#{System.unique_integer([:positive])}@example.com"

  defp json_conn(%{conn: conn}) do
    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
  end

  describe "POST /powapi/reset-password" do
    test "sends a reset email for a registered address", ctx do
      email = unique_email("reset")
      insert(:user, email: email)

      body =
        ctx
        |> json_conn()
        |> post("/powapi/reset-password", %{"user" => %{"email" => email}})
        |> json_response(200)

      assert body["ok"] == true

      wait_for_emails([sent])
      assert {_, ^email} = hd(sent.to)
    end

    test "responds ok without sending for an unknown address (no enumeration)", ctx do
      body =
        ctx
        |> json_conn()
        |> post("/powapi/reset-password", %{"user" => %{"email" => unique_email("nobody")}})
        |> json_response(200)

      # Indistinguishable from the hit case — same body, and nothing sent.
      assert body["ok"] == true
      assert SwooshHelper.sent_email() == []
    end

    test "422 when the email param is missing", ctx do
      body =
        ctx
        |> json_conn()
        |> post("/powapi/reset-password", %{"user" => %{}})
        |> json_response(422)

      assert body["error"]["code"] == "invalid_params"
    end
  end
end
