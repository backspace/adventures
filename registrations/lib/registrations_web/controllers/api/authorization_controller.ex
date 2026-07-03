# Adapted from https://hexdocs.pm/pow_assent/0.4.18/api.html

defmodule RegistrationsWeb.ApiAuthorizationController do
  use RegistrationsWeb, :controller

  alias Plug.Conn
  alias PowAssent.Plug

  # Custom URI scheme the Flutter app registers for OAuth callbacks.
  # Google's Web-type OAuth client won't accept a custom scheme as an
  # Authorized redirect URI directly, so we register the HTTPS
  # `mobile_bounce` URL in Google Console and let it hand off to the
  # scheme via a 302 (see `mobile_bounce/2`).
  @mobile_scheme "ca.chromatin.poles"

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, %{"provider" => provider}) do
    conn
    |> Plug.authorize_url(provider, redirect_uri(conn))
    |> case do
      {:ok, url, conn} ->
        json(conn, %{data: %{url: url, session_params: conn.private[:pow_assent_session_params]}})

      {:error, _error, conn} ->
        conn
        |> put_status(500)
        |> json(%{error: %{status: 500, message: "An unexpected error occurred"}})
    end
  end

  # Web clients use the direct POST /callback URL; mobile clients pass
  # `client=mobile` and get the bounce URL so Google can 302 to it and
  # we can then 302 the browser to the app's custom scheme.
  defp redirect_uri(conn) do
    case conn.params["client"] do
      "mobile" -> Routes.api_authorization_url(conn, :mobile_bounce, conn.params["provider"])
      _ -> Routes.api_authorization_url(conn, :callback, conn.params["provider"])
    end
  end

  @spec callback(Conn.t(), map()) :: Conn.t()
  def callback(conn, %{"provider" => provider} = params) do
    session_params = Map.fetch!(params, "session_params")
    params         = Map.drop(params, ["provider", "session_params"])

    conn
    |> Conn.put_private(:pow_assent_session_params, session_params)
    |> Plug.callback_upsert(provider, params, redirect_uri(conn))
    |> case do
      {:ok, conn} ->
        json(conn, %{data: %{access_token: conn.private.api_access_token, renewal_token: conn.private.api_renewal_token}})

      {:error, conn} ->
        conn
        |> put_status(500)
        |> json(%{error: %{status: 500, message: "An unexpected error occurred"}})
    end
  end

  # Google → 302 to this URL (whitelisted as an authorized redirect on
  # the Google Web OAuth client). We forward `code`, `state`, and
  # `error` on to the app's custom URI scheme; the app's
  # `flutter_web_auth_2` handler intercepts the scheme and closes
  # `ASWebAuthenticationSession`/Custom Tabs, returning the URL to the
  # Dart caller which then POSTs it to `/callback` above.
  @spec mobile_bounce(Conn.t(), map()) :: Conn.t()
  def mobile_bounce(conn, params) do
    query =
      params
      |> Map.take(["code", "state", "error"])
      |> URI.encode_query()

    redirect(conn, external: "#{@mobile_scheme}://oauth-callback?#{query}")
  end
end
