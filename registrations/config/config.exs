# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

config :logger, :console,
  # Configures the endpoint
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :registrations, Registrations.Mailer,
  adapter: Swoosh.Adapters.Mailgun,
  domain: "mg.chromatin.ca"

config :registrations, RegistrationsWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST") || "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "xn64PMB42eKmnISH1qTC8I+r62bNyMgTxlXYupsWCvvjBnFJEycMHcXdeFitYxyS",
  render_errors: [accepts: ~w(html json)],
  pubsub_server: Registrations.PubSub

# Configures Elixir's Logger
config :registrations,
  placeholder: false,
  start_time: [{{2017, 6, 8}, {18, 00, 00}}, "Canada/Pacific"],
  location: "Zagreb",
  base_url: "http://example.com"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :phoenix, :generators,
  # Use Jason for JSON parsing in Phoenix
  migration: true,
  binary_id: false

config :phoenix, :json_library, Jason

config :registrations, Registrations.Repo, types: Registrations.Waydowntown.PostgresTypes

config :registrations, :pow,
  web_mailer_module: RegistrationsWeb,
  extensions: [PowResetPassword, PowInvitation, PowPersistentSession],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  web_module: RegistrationsWeb,
  user: RegistrationsWeb.User,
  repo: Registrations.Repo,
  routes_backend: RegistrationsWeb.Pow.Routes,
  mailer_backend: Registrations.Mailer,
  messages_backend: RegistrationsWeb.Pow.Messages,
  users_context: RegistrationsWeb.Pow.Users

config :registrations, :pow_assent, user_identities_context: RegistrationsWeb.PowAssent.UserIdentities

# Configure phoenix generators
config :registrations, ecto_repos: [Registrations.Repo]
