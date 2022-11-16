import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :adventure_registrations, AdventureRegistrationsWeb.Endpoint,
  http: [port: 4001],
  server: true

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :adventure_registrations, AdventureRegistrations.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "adventure_registrations_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :hound, driver: "chrome_driver", browser: "chrome_headless"

config :comeonin, :bcrypt_log_rounds, 4

defmodule Blacksmith.Config do
  def save(map) do
    AdventureRegistrations.Repo.insert(map)
  end

  def save_all(list) do
    Enum.map(list, &AdventureRegistrations.Repo.insert/1)
  end
end

config :adventure_registrations, mailgun_mode: :test, mailgun_test_file_path: "/tmp/mailgun.json"
