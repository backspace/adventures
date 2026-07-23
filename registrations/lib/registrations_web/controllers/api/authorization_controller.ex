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
         {:ok, user_identity_params, user_params, verified_email} <-
           build_upsert_params(claims, client_user),
         {:ok, user} <-
           find_or_create_apple_user(user_identity_params, user_params, verified_email) do
      conn = Pow.Plug.create(conn, user, Pow.Plug.fetch_config(conn))

      json(conn, %{
        data: %{
          access_token: conn.private.api_access_token,
          renewal_token: conn.private.api_renewal_token
        }
      })
    else
      # New Apple user, but Apple withheld the email (it's only returned on the
      # FIRST authorization ever for this Apple ID). We can't create an
      # email-keyed account without one, so ask the app to collect an email and
      # resubmit the same token. 422 + this code is distinct from the 401
      # rejection below so the client can tell "need email" from "bad token".
      {:error, :email_required} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "email_required", message: "Apple didn’t share an email; please provide one."}})

      {:error, reason} ->
        require Logger
        Logger.warning("Apple native sign-in rejected: #{inspect(reason)}")

        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{status: 401, message: "Apple sign-in rejected", detail: inspect(reason)}})
    end
  end

  # Verifies the Apple identity token against Apple's public keys. Overridable
  # in tests (config `:apple_id_token_validator`, a `fn config, token -> ... end`)
  # so the link/create/email_required branches can be exercised locally without
  # a real Apple-signed token — the SDK + signature path still needs a device.
  defp validate_apple_id_token(apple_config, id_token) do
    case Application.get_env(:registrations, :apple_id_token_validator) do
      fun when is_function(fun, 2) -> fun.(apple_config, id_token)
      _ -> Assent.Strategy.OIDC.validate_id_token(apple_config, id_token)
    end
  end

  defp build_upsert_params(%{"sub" => sub} = claims, client_user) do
    # Apple-verified email (from the signed token) is the ONLY email we'll
    # trust to link into an existing account. A manually-entered prompt email
    # arrives via `client_user` and must never link — only create.
    verified_email =
      if claims["email_verified"] in [true, "true"], do: claims["email"], else: nil

    email = claims["email"] || Map.get(client_user, "email")

    user_identity_params = %{"provider" => "apple", "uid" => sub}
    user_params = maybe_put_name(%{"email" => email}, client_user)

    {:ok, user_identity_params, user_params, verified_email}
  end

  defp build_upsert_params(_claims, _client_user), do: {:error, :missing_sub}

  defp maybe_put_name(user_params, %{"given_name" => given, "family_name" => family})
       when is_binary(given) or is_binary(family) do
    name = [given, family] |> Enum.reject(&is_nil/1) |> Enum.join(" ") |> String.trim()
    if name == "", do: user_params, else: Map.put(user_params, "name", name)
  end

  defp maybe_put_name(user_params, _), do: user_params

  # First lookup by (provider, uid). If found, return that user (a returning
  # sign-in needs no email — Apple's stable `uid` is the identity). If not
  # found, create — but only if we actually have an email; otherwise signal
  # `:email_required` so the app can collect one and resubmit, rather than
  # letting the User changeset fail on a blank email.
  defp find_or_create_apple_user(user_identity_params, user_params, verified_email) do
    import Ecto.Query

    existing =
      Registrations.Repo.one(
        from(ui in Registrations.UserIdentities.UserIdentity,
          where: ui.provider == ^user_identity_params["provider"] and ui.uid == ^user_identity_params["uid"],
          preload: [:user]
        )
      )

    cond do
      # Returning Apple user — logged in by their stable uid, no email needed.
      match?(%{user: %{}}, existing) ->
        {:ok, existing.user}

      # No email at all — ask the app to collect one and resubmit.
      blank?(user_params["email"]) ->
        {:error, :email_required}

      true ->
        link_or_create(user_identity_params, user_params, verified_email)
    end
  end

  # Link the Apple identity to an EXISTING account when Apple gave us a
  # verified email that matches one (so "Sign in with Apple" logs into the
  # account you already have). Otherwise create. Only the Apple-verified email
  # may link — a manually-entered one can only create, so nobody can attach
  # their Apple ID to someone else's account by typing that person's address.
  defp link_or_create(user_identity_params, user_params, verified_email) do
    existing_user =
      verified_email &&
        Registrations.Repo.get_by(RegistrationsWeb.User, email: String.downcase(verified_email))

    case existing_user do
      %RegistrationsWeb.User{} = user ->
        case RegistrationsWeb.PowAssent.UserIdentities.upsert(user, user_identity_params) do
          {:ok, _identity} -> {:ok, user}
          {:error, _reason} -> {:error, :link_failed}
        end

      _ ->
        # nil (not %{}) as the third arg is load-bearing: PowAssent takes the
        # email from `user_params` only when `user_id_params` is nil — pass a
        # map and it reads the email from THAT instead, dropping ours.
        RegistrationsWeb.PowAssent.UserIdentities.create_user(user_identity_params, user_params, nil)
    end
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: false
end
