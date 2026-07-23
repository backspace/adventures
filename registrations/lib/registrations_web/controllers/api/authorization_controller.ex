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

  # Providers → this URL (registered as an authorized redirect on the
  # respective OAuth client). We forward `code`, `state`, and `error`
  # on to the app's custom URI scheme; the app's `flutter_web_auth_2`
  # handler intercepts the scheme and closes ASWebAuthenticationSession
  # or Custom Tabs, returning the URL to the Dart caller which POSTs
  # it to `/callback`.
  #
  # Handles both GET (Google, `response_mode: "query"`) and POST
  # (Apple, `response_mode: "form_post"` — mandatory whenever email or
  # name scope is requested). Form-encoded body params get merged into
  # `conn.params` by `Plug.Parsers`, so the extraction is identical.
  #
  # Rather than a server-side redirect with a custom-scheme Location
  # header (which Chrome Custom Tabs on Android often refuses to
  # follow, leaving the tab stuck on a blank loading page), we return
  # a small HTML page that fires the scheme via meta-refresh + JS
  # `location.replace`. Chrome dispatches an in-page navigation to a
  # non-HTTP scheme to the OS intent handler consistently — which is
  # what closes the tab and calls back into `flutter_web_auth_2`.
  @spec mobile_bounce(Conn.t(), map()) :: Conn.t()
  def mobile_bounce(conn, params) do
    query =
      params
      |> Map.take(["code", "state", "error"])
      |> URI.encode_query()

    target = "#{@mobile_scheme}://oauth-callback?#{query}"
    # Fully-qualify to bypass the `alias PowAssent.Plug` at the top of
    # this file, which would otherwise shadow `Plug` and resolve to
    # `PowAssent.Plug.HTML` (nonexistent).
    target_attr = Elixir.Plug.HTML.html_escape(target)
    target_js = Jason.encode!(target)

    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Returning to the app…</title>
      <meta http-equiv="refresh" content="0;url=#{target_attr}">
      <script>window.location.replace(#{target_js});</script>
      <style>
        body { font-family: -apple-system, system-ui, sans-serif;
               display: flex; align-items: center; justify-content: center;
               height: 100vh; margin: 0; text-align: center; color: #333; }
        a { display: inline-block; margin-top: 1rem; }
      </style>
    </head>
    <body>
      <div>
        <p>Returning to the app…</p>
        <a href="#{target_attr}">Tap here if you're not redirected automatically.</a>
      </div>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  # Native Sign in with Apple on iOS — the `sign_in_with_apple` package
  # returns an identity token JWT signed by Apple. We verify the JWT
  # against Apple's public keys directly (no OAuth code exchange, no
  # OAuth state to validate) and upsert the user based on the `sub`
  # (Apple's stable per-user, per-app id).
  #
  # Body:
  #   identity_token: JWT string from `AppleIDCredential.identityToken`
  #   user:           optional map with :email / :given_name /
  #                   :family_name — Apple only returns these on the
  #                   FIRST sign-in, so the app forwards whatever it
  #                   received; we lean on them for account creation.
  @spec apple_native_callback(Conn.t(), map()) :: Conn.t()
  def apple_native_callback(conn, %{"identity_token" => id_token} = params) do
    bundle_id = Application.fetch_env!(:registrations, :apple_bundle_id)

    # Verifying the token needs the OIDC issuer + provider config (base_url,
    # openid_configuration/jwks_uri). Those come from the Apple strategy's
    # defaults — a hand-built `[client_id: ...]` omits them and
    # `validate_id_token` fails with `MissingKeyError{key: :base_url}`. We only
    # override `client_id`: a NATIVE identity token's `aud` is the app's Bundle
    # ID, not the web Services ID.
    # `session_params` normally carries the OAuth `nonce`/`state` from the
    # authorization request, but the native SDK flow has no such round-trip
    # and the client sends no nonce — so the token carries none either.
    # validate_id_token still *requires the key to exist*; an empty map
    # passes nonce validation (nothing on either side to compare).
    apple_config =
      Assent.Strategy.Apple.default_config([])
      |> Keyword.put(:client_id, bundle_id)
      |> Keyword.put(:session_params, %{})

    client_user = Map.get(params, "user", %{})

    with {:ok, jwt} <- validate_apple_id_token(apple_config, id_token),
         claims = jwt.claims,
         {:ok, user_identity_params, user_params} <- build_upsert_params(claims, client_user),
         {:ok, user} <- find_or_create_apple_user(user_identity_params, user_params) do
      conn = Pow.Plug.create(conn, user, Pow.Plug.fetch_config(conn))

      json(conn, %{
        data: %{
          access_token: conn.private.api_access_token,
          renewal_token: conn.private.api_renewal_token
        }
      })
    else
      {:error, reason} ->
        require Logger
        Logger.warning("Apple native sign-in rejected: #{inspect(reason)}")

        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{status: 401, message: "Apple sign-in rejected", detail: inspect(reason)}})
    end
  end

  defp validate_apple_id_token(apple_config, id_token) do
    Assent.Strategy.OIDC.validate_id_token(apple_config, id_token)
  end

  defp build_upsert_params(%{"sub" => sub} = claims, client_user) do
    email = claims["email"] || Map.get(client_user, "email")

    user_identity_params = %{"provider" => "apple", "uid" => sub}
    user_params = maybe_put_name(%{"email" => email}, client_user)

    {:ok, user_identity_params, user_params}
  end

  defp build_upsert_params(_claims, _client_user), do: {:error, :missing_sub}

  defp maybe_put_name(user_params, %{"given_name" => given, "family_name" => family})
       when is_binary(given) or is_binary(family) do
    name = [given, family] |> Enum.reject(&is_nil/1) |> Enum.join(" ") |> String.trim()
    if name == "", do: user_params, else: Map.put(user_params, "name", name)
  end

  defp maybe_put_name(user_params, _), do: user_params

  # First lookup by (provider, uid). If found, return that user; if
  # not, invoke our custom UserIdentities.create_user so the same
  # welcome-email hook fires as the web-flow path.
  defp find_or_create_apple_user(user_identity_params, user_params) do
    import Ecto.Query

    existing =
      Registrations.Repo.one(
        from(ui in Registrations.UserIdentities.UserIdentity,
          where: ui.provider == ^user_identity_params["provider"] and ui.uid == ^user_identity_params["uid"],
          preload: [:user]
        )
      )

    case existing do
      %{user: user} -> {:ok, user}
      nil -> RegistrationsWeb.PowAssent.UserIdentities.create_user(user_identity_params, user_params, %{})
    end
  end
end
