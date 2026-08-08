defmodule RegistrationsWeb.Plugs.RegistrationClosedTest do
  @moduledoc """
  The real close: when `registration_closed` is set, the self-signup endpoints
  create no accounts. The separate `registration_warning` flag only banners and
  is not exercised here.
  """
  use RegistrationsWeb.ConnCase

  alias RegistrationsWeb.User
  alias Registrations.Repo

  setup do
    # The site layout renders adventure-specific copy, so the register page
    # needs an adventure configured to render.
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :adventure,
      "clandestine-rendezvous"
    )

    :ok
  end

  defp close! do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :registration_closed,
      true
    )
  end

  describe "when registration is closed" do
    setup do: close!()

    test "POST /registration creates no account and redirects home", %{conn: conn} do
      before = Repo.aggregate(User, :count)

      conn =
        post(conn, "/registration", %{
          "user" => %{
            "email" => "spam@example.com",
            "password" => "password1234",
            "password_confirmation" => "password1234"
          }
        })

      assert redirected_to(conn) == "/"
      assert Repo.aggregate(User, :count) == before
    end

    test "GET /registration/new redirects home instead of showing the form", %{conn: conn} do
      assert redirected_to(get(conn, "/registration/new")) == "/"
    end

    test "POST /questions (pre-registration form) is blocked", %{conn: conn} do
      conn =
        post(conn, "/questions", %{
          "question" => %{
            "name" => "Spammer",
            "email" => "spam@example.com",
            "subject" => "hi",
            "question" => "?"
          }
        })

      assert redirected_to(conn) == "/"
    end

    test "POST /powapi/registration is forbidden", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post("/powapi/registration", %{
          "user" => %{"email" => "spam2@example.com", "password" => "password1234"}
        })

      assert conn.status == 403
    end
  end

  test "the sign-up form renders normally when registration is open", %{conn: conn} do
    # Flag defaults off in test — the plug is a no-op and Pow serves the form.
    assert html_response(get(conn, "/registration/new"), 200) =~ "Register"
  end
end
