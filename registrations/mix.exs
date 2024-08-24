defmodule Registrations.Mixfile do
  use Mix.Project

  def project do
    [
      app: :registrations,
      version: "0.0.1",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {Registrations.Application, []}, extra_applications: [:logger]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.12.2"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_view, "~> 0.17.11"},
      {:gettext, "~> 0.9"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:plug_cowboy, "~> 2.1"},
      {:plug, "~> 1.7"},
      {:pow, "~> 1.0.28"},
      {:pow_assent, "~> 0.4.15"},
      {:redix, "~> 1.5.1"},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:hound, github: "backspace/hound", ref: "malgasm-plus-warning-fixes", only: :test},
      {:ex_machina, "~> 2.7.0", only: :test},
      {:bcrypt_elixir, "~> 3.0"},
      {:swoosh, "~> 1.9"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:premailex, "~> 0.3.19"},
      {:jason, "~> 1.0"},
      {:ex_cldr, "~> 2.33"},
      {:ex_cldr_numbers, "~> 2.28"},
      {:ex_cldr_lists, "~> 2.10"},
      {:floki, "~> 0.34"},
      {:tzdata, "~> 1.1"},
      {:junit_formatter, "~> 3.3", only: [:test]},
      {:wait_for_it, "~> 1.3", only: [:test]},
      {:sentry, "~> 10.0"},
      {:hackney, "~> 1.19"},
      {:assertions, "0.19.0", only: :test},
      {:jsonapi, "~> 1.8"},
      {:styler, "~> 1.0.0"}
    ]
  end

  # Aliases are shortcut or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "db.migrate": [
        "ecto.migrate",
        "ecto.dump -d ../unmnemonic_devices_vrs/tests/fixtures/schema.sql",
        "cmd ./lib/dump-waydowntown-server-schema.sh"
      ],
      "db.rollback": [
        "ecto.rollback",
        "ecto.dump -d ../unmnemonic_devices_vrs/tests/fixtures/schema.sql",
        "cmd ./lib/dump-waydowntown-server-schema.sh"
      ],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
