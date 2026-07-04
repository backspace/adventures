defmodule RegistrationsWeb.SessionExchangeController do
  @moduledoc """
  Bridges API-token authentication (the mobile app) to browser-cookie
  authentication (the registrations site), so the app can open pages
  from the site inside an in-app WebView without asking the user to
  sign in a second time.

  Flow:

    1. Mobile app calls `POST /powapi/session/exchange` with a valid
       API access token. Server mints a short-lived signed URL like
       `https://landgrab.chromatin.ca/session/exchange?token=…`.
    2. App opens that URL in a WebView.
    3. `GET /session/exchange` verifies the token, creates a Pow
       browser session for the same user, and redirects to `/details`.

  The signed token is a `Phoenix.Token` — HMAC-signed with the
  endpoint's `secret_key_base` — so nothing beyond the user id is
  crossing over. TTL is short (60s) because the URL should be
  consumed immediately by the WebView.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Repo

  @token_salt "api-to-web-session"
  @token_max_age 60

  # POST /powapi/session/exchange
  # API-authenticated. Returns { data: { url: "…?token=…" } }.
  def mint(conn, _params) do
    case Pow.Plug.current_user(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{status: 401, message: "Not authenticated"}})

      user ->
        token = Phoenix.Token.sign(conn, @token_salt, user.id)
        base = Application.get_env(:registrations, :base_url) || ""
        url = "#{base}/session/exchange?token=#{token}"
        json(conn, %{data: %{url: url}})
    end
  end

  # GET /session/exchange?token=…
  # Browser-side. Verifies the signed token, establishes a Pow
  # session cookie for the user, redirects to /details.
  def redeem(conn, %{"token" => token}) do
    case Phoenix.Token.verify(conn, @token_salt, token, max_age: @token_max_age) do
      {:ok, user_id} ->
        case Repo.get(RegistrationsWeb.User, user_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> text("Account no longer exists.")

          user ->
            conn
            |> Pow.Plug.create(user, Pow.Plug.fetch_config(conn))
            |> redirect(to: Routes.user_path(conn, :edit))
        end

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> text("Sign-in link expired or invalid. Return to the app and try again.")
    end
  end

  def redeem(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> text("Missing token.")
  end
end
