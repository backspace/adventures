defmodule RegistrationsWeb.Api.AuthorizationAppleNativeTest do
  @moduledoc """
  Local simulation of native Sign in with Apple. Apple's signed identity
  token can't be forged, so `validate_apple_id_token` is stubbed via the
  `:apple_id_token_validator` config to return crafted claims — letting us
  exercise the link / create / email-required / returning-uid branches
  deterministically. The SDK + signature verification still needs a device.
  """
  use RegistrationsWeb.ConnCase
  # Account creation fires the welcome email, whose copy is per-adventure
  # gettext — set one so it resolves instead of crashing on a nil domain.
  use Registrations.SetAdventure, adventure: "landgrab"

  import Registrations.Factory

  alias Registrations.Repo
  alias Registrations.UserIdentities.UserIdentity

  @path "/powapi/auth/apple/native_callback"

  setup do
    Application.put_env(:registrations, :apple_bundle_id, "ca.chromatin.poles")
    on_exit(fn -> Application.delete_env(:registrations, :apple_bundle_id) end)
    :ok
  end

  # Stub token verification to return these exact claims for any token.
  defp stub_claims(claims) do
    Application.put_env(
      :registrations,
      :apple_id_token_validator,
      fn _config, _token -> {:ok, %{claims: claims}} end
    )

    on_exit(fn -> Application.delete_env(:registrations, :apple_id_token_validator) end)
  end

  defp post_callback(conn, body) do
    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
    |> post(@path, body)
  end

  defp apple_identity(uid), do: Repo.get_by(UserIdentity, provider: "apple", uid: uid)

  test "returns email_required (422) for a new Apple user with no email", %{conn: conn} do
    stub_claims(%{"sub" => "apple-uid-none"})

    body = post_callback(conn, %{"identity_token" => "tok"}) |> json_response(422)
    assert body["error"]["code"] == "email_required"
    refute apple_identity("apple-uid-none")
  end

  test "creates a new account when Apple gives a verified email and none matches",
       %{conn: conn} do
    stub_claims(%{
      "sub" => "apple-uid-new",
      "email" => "fresh@example.com",
      "email_verified" => "true"
    })

    body = post_callback(conn, %{"identity_token" => "tok"}) |> json_response(200)
    assert body["data"]["access_token"]
    assert Repo.get_by(RegistrationsWeb.User, email: "fresh@example.com")
    assert apple_identity("apple-uid-new")
  end

  test "links to an existing account when the verified email matches", %{conn: conn} do
    user = insert(:user, email: "existing@example.com")

    stub_claims(%{
      "sub" => "apple-uid-link",
      "email" => "existing@example.com",
      "email_verified" => "true"
    })

    body = post_callback(conn, %{"identity_token" => "tok"}) |> json_response(200)
    assert body["data"]["access_token"]

    # The Apple identity is attached to the SAME user — no duplicate account.
    identity = apple_identity("apple-uid-link")
    assert identity.user_id == user.id
    assert Repo.aggregate(from(u in RegistrationsWeb.User, where: u.email == "existing@example.com"), :count) == 1
  end

  test "logs a returning Apple user in by uid, no email needed", %{conn: conn} do
    user = insert(:user, email: "returning@example.com")
    Repo.insert!(%UserIdentity{provider: "apple", uid: "apple-uid-return", user_id: user.id})

    # No email in the token at all — a repeat sign-in.
    stub_claims(%{"sub" => "apple-uid-return"})

    body = post_callback(conn, %{"identity_token" => "tok"}) |> json_response(200)
    assert body["data"]["access_token"]
  end

  test "a MANUALLY-entered email never links to someone else's account", %{conn: conn} do
    victim = insert(:user, email: "victim@example.com")

    # Apple sent no verified email; the attacker types the victim's address in
    # the app's prompt (arrives as `user.email`, not a token claim).
    stub_claims(%{"sub" => "apple-uid-attacker"})

    body =
      post_callback(conn, %{
        "identity_token" => "tok",
        "user" => %{"email" => "victim@example.com"}
      })
      |> json_response(401)

    assert body["error"]["message"] == "Apple sign-in rejected"
    # The victim's account gained no Apple identity.
    refute apple_identity("apple-uid-attacker")
    assert Repo.get(RegistrationsWeb.User, victim.id).id == victim.id
  end
end
