# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# Configures the endpoint
config :adventure_registrations, AdventureRegistrationsWeb.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "xn64PMB42eKmnISH1qTC8I+r62bNyMgTxlXYupsWCvvjBnFJEycMHcXdeFitYxyS",
  render_errors: [accepts: ~w(html json)],
  pubsub_server: AdventureRegistrations.PubSub

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :adventure_registrations, AdventureRegistrations.Mailer,
  adapter: Swoosh.Adapters.Mailgun,
  domain: "mg.chromatin.ca"

config :adventure_registrations,
  start_time: [{{2017, 6, 8}, {18, 00, 00}}, "Canada/Pacific"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure phoenix generators
config :phoenix, :generators,
  migration: true,
  binary_id: false

config :porcelain, driver: Porcelain.Driver.Basic

config :adventure_registrations, ecto_repos: [AdventureRegistrations.Repo]
