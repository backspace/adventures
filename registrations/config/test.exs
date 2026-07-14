import Config

config :wallaby,
  driver: Wallaby.Chrome,
  chrome: [headless: true],
  base_url: "http://localhost:4001",
  js_errors: false

# Print only warnings and errors during test
config :logger, level: :warning

config :registrations, Registrations.Mailer, adapter: Swoosh.Adapters.Local

# The polling announcer would fight the Ecto sandbox; the underlying
# maybe_announce_endgame/1 is tested directly.
config :registrations, start_endgame_announcer: false

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
  http: [ip: {0, 0, 0, 0}, port: 4001],
  server: true,
  check_origin: false
