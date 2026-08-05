import Config

# Onboarding install links, rendered as printable full-page QR posters
# at /install (see RegistrationsWeb.InstallController). Set per deploy;
# a blank/unset link shows a "not configured" placeholder on that page
# instead of a QR. Kept out of committed config so event-specific links
# (TestFlight, testing-group, store/APK URLs) aren't published.
config :registrations, :onboarding_links,
  ios_testflight: System.get_env("ONBOARDING_IOS_TESTFLIGHT"),
  ios_install: System.get_env("ONBOARDING_IOS_INSTALL"),
  android_group: System.get_env("ONBOARDING_ANDROID_GROUP"),
  android_install: System.get_env("ONBOARDING_ANDROID_INSTALL")

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/phoenixnew start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :registrations, RegistrationsWeb.Endpoint, server: true
end

unless config_env() == :test do
  adventure =
    System.get_env("ADVENTURE") ||
      raise """
      environment variable ADVENTURE is missing.
      """

  config :registrations,
    adventure: adventure
end

spam_strings =
  "SPAM_STRINGS"
  |> System.get_env("")
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)

config :registrations,
  spam_strings: spam_strings

# Whether to show the placeholder page to unauthenticated visitors.
# Read at boot so staging/prod can flip it via a Coolify env-var change
# + restart, with no redeploy. Defaults to false when unset.
config :registrations,
  placeholder: System.get_env("PLACEHOLDER") == "true"

# Distinguishes deployments (production vs staging vs local) so the layout
# can advertise non-production environments visually. Defaults to the
# `config_env()` name when DEPLOY_ENV isn't set — so prod machines that
# don't opt in are still labelled "production".
deploy_env =
  System.get_env("DEPLOY_ENV") ||
    case config_env() do
      :prod -> "production"
      :dev -> "development"
      :test -> "test"
    end

config :registrations,
  deploy_env: deploy_env

# Use the Redis-backed Pow cache whenever REDIS_URL is set, so sessions persist
# across server restarts. Required in prod; optional in dev (set REDIS_URL to
# opt in to persistent local sessions). Application.ex starts the Redix child
# on the same condition.
if System.get_env("REDIS_URL") do
  config :registrations, :pow, cache_store_backend: RegistrationsWeb.Pow.RedisCache
end

if config_env() == :prod do
  location =
    System.get_env("LOCATION") ||
      raise """
      environment variable LOCATION is missing.
      """

  base_url =
    System.get_env("BASE_URL") ||
      raise """
      environment variable BASE_URL is missing.
      """

  start_time_string =
    System.get_env("START_TIME") ||
      raise """
      environment variable START_TIME is missing.
      """

  start_timezone =
    System.get_env("START_TIMEZONE") ||
      raise """
      environment variable START_TIMEZONE is missing.
      """

  start_time =
    case Calendar.ISO.parse_naive_datetime(start_time_string) do
      {:ok, {year, month, day, hour, minute, second, _microsecond}} ->
        [{{year, month, day}, {hour, minute, second}}, start_timezone]

      _ ->
        raise "Failed to parse START_TIME"
    end

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  sentry_dsn =
    System.get_env("SENTRY_DSN") ||
      raise """
      environment variable SENTRY_DSN is missing.
      """

  mailgun_api_key =
    System.get_env("MAILGUN_API_KEY") ||
      raise """
      environment variable MAILGUN_API_KEY is missing.
      """

  mailgun_domain =
    System.get_env("MAILGUN_DOMAIN") ||
      raise """
      environment variable MAILGUN_DOMAIN is missing.
      """

  System.get_env("REDIS_URL") ||
    raise """
    environment variable REDIS_URL is missing.
    The Pow session cache is backed by Redis in production; without it
    POST /session and all authenticated requests will crash with :noproc.
    """

  config :registrations, Registrations.Mailer,
    adapter: Swoosh.Adapters.Mailgun,
    api_key: mailgun_api_key,
    domain: mailgun_domain

  config :registrations, Registrations.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :registrations, RegistrationsWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :registrations,
    location: location,
    base_url: base_url,
    start_time: start_time

  # Feature flags read at boot, so staging/prod can flip them via a Coolify
  # env-var change + restart, with no redeploy. Each defaults to false unless
  # its var is exactly "true".
  #   REQUEST_CONFIRMATION — the user details form shows (and requires) the
  #     "Are you attending?" field (see user.ex details_changeset and
  #     user/edit.html.heex).
  #   REGISTRATION_CLOSED — new sign-ups are closed (see user_controller.ex
  #     and register_or_accept_invitation.html.eex).
  config :registrations,
    request_confirmation: System.get_env("REQUEST_CONFIRMATION") == "true",
    registration_closed: System.get_env("REGISTRATION_CLOSED") == "true"

  config :sentry, dsn: sentry_dsn

  # Optional OAuth providers. Each is wired in only when its full set
  # of env vars is present; missing vars just mean the button won't
  # render and email/password remains the only path. A single
  # `config :registrations, :pow_assent, providers: […]` call replaces
  # the whole list, so we build a keyword list conditionally and set
  # it once at the end.
  oauth_providers =
    []
    |> then(fn acc ->
      google_client_id = System.get_env("GOOGLE_CLIENT_ID")
      google_client_secret = System.get_env("GOOGLE_CLIENT_SECRET")

      if google_client_id && google_client_secret do
        acc ++
          [
            google: [
              client_id: google_client_id,
              client_secret: google_client_secret,
              strategy: Assent.Strategy.Google
            ]
          ]
      else
        acc
      end
    end)
    |> then(fn acc ->
      apple_client_id = System.get_env("APPLE_CLIENT_ID")
      apple_team_id = System.get_env("APPLE_TEAM_ID")
      apple_key_id = System.get_env("APPLE_KEY_ID")
      apple_private_key = System.get_env("APPLE_PRIVATE_KEY")

      if apple_client_id && apple_team_id && apple_key_id && apple_private_key do
        acc ++
          [
            apple: [
              client_id: apple_client_id,
              team_id: apple_team_id,
              private_key_id: apple_key_id,
              private_key: apple_private_key,
              # Apple rejects `response_mode: "query"` whenever `name`
              # or `email` scope is requested and returns
              # `invalid_request: response_mode must be form_post…`.
              # We keep Assent's default `form_post` and handle the
              # POST at `mobile_bounce` — the endpoint 303s to the
              # custom URI scheme regardless of which method Apple
              # (or Google, which uses GET) used to reach it.
              strategy: Assent.Strategy.Apple
            ]
          ]
      else
        acc
      end
    end)

  if oauth_providers != [] do
    config :registrations, :pow_assent, providers: oauth_providers
  end

  # Apple Bundle ID — used only for verifying identity tokens returned
  # by the native iOS Sign in with Apple SDK (the JWT's `aud` claim
  # must match). Separate from the Services ID (`APPLE_CLIENT_ID`)
  # because native flow uses the app's Bundle ID as its audience while
  # the web flow uses the Services ID.
  if apple_bundle_id = System.get_env("APPLE_BUNDLE_ID") do
    config :registrations, :apple_bundle_id, apple_bundle_id
  end

  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
