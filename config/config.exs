# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :cr2016site, Cr2016site.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "xn64PMB42eKmnISH1qTC8I+r62bNyMgTxlXYupsWCvvjBnFJEycMHcXdeFitYxyS",
  render_errors: [accepts: ~w(html json)],
  pubsub: [name: Cr2016site.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :cr2016site,
  mailgun_domain: "https://api.mailgun.net/v3/mg.chromatin.ca",
  mailgun_mode: :regular,
  start_time: [{{2018, 3, 6}, {18, 30, 00}}, "Canada/Central"],
  email_address: "beyond@chromatin.ca",
  email_short_adventure_name: "beyond",
  host: System.get_env("HOST")

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  included_environments: [:prod],
  environment_name: Mix.env()

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"

# Configure phoenix generators
config :phoenix, :generators,
  migration: true,
  binary_id: false

config :porcelain, driver: Porcelain.Driver.Basic

config :cr2016site, ecto_repos: [Cr2016site.Repo]
