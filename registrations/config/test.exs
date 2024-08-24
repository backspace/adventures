import Config

config :hound, driver: "chrome_driver", browser: "chrome_headless"

# Print only warnings and errors during test
config :logger, level: :warning

config :registrations, Registrations.Mailer, adapter: Swoosh.Adapters.Local

# Configure your database
config :registrations, Registrations.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "registrations_test",
  hostname: "localhost",
  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  pool: Ecto.Adapters.SQL.Sandbox

config :registrations, RegistrationsWeb.Endpoint,
  http: [port: 4001],
  server: true
