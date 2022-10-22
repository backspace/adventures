use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :cr2016site, Cr2016siteWeb.Endpoint,
  http: [port: 4001],
  server: true

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :cr2016site, Cr2016site.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "cr2016site_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :hound, driver: "chrome_driver", browser: "chrome_headless"

config :comeonin, :bcrypt_log_rounds, 4

defmodule Blacksmith.Config do
  def save(map) do
    Cr2016site.Repo.insert(map)
  end

  def save_all(list) do
    Enum.map(list, &Cr2016site.Repo.insert/1)
  end
end

config :cr2016site, mailgun_mode: :test, mailgun_test_file_path: "/tmp/mailgun.json"
