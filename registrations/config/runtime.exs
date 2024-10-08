import Config

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

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  config :registrations, Registrations.Mailer,
    adapter: Swoosh.Adapters.Mailgun,
    api_key: System.get_env("MAILGUN_API_KEY"),
    domain: System.get_env("MAILGUN_DOMAIN")

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

  config :sentry, dsn: sentry_dsn

  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
