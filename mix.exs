defmodule AdventureRegistrations.Mixfile do
  use Mix.Project

  def project do
    [
      app: :adventure_registrations,
      version: "0.0.1",
      elixir: "~> 1.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
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
    [mod: {AdventureRegistrations.Application, []}, applications: app_list(Mix.env())]
  end

  def app_list do
    [
      :phoenix,
      :phoenix_pubsub,
      :phoenix_html,
      :cowboy,
      :logger,
      :phoenix_ecto,
      :postgrex,
      :gettext,
      :tzdata,
      :porcelain,
      :comeonin,
      :crutches,
      :ecto_sql,
      :swoosh,
      :phoenix_live_view,
      :timex,
    ]
  end

  def app_list(:dev), do: [:phoenix_live_reload] ++ app_list()
  def app_list(:test), do: [:blacksmith, :hound] ++ app_list()
  def app_list(_), do: app_list()

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
      {:mix_test_watch, "~> 0.2.6", only: :dev},
      {:hound, "~> 1.1.1", only: :test},
      {:blacksmith, "~> 0.2.1"},
      {:comeonin, "~> 1.0"},
      {:swoosh, "~> 1.9"},
      {:jason, "~> 1.0"},
      {:poison, "~> 2.0"},
      {:crutches, git: "https://github.com/mykewould/crutches.git"},
      {:floki, "~> 0.7"},
      {:timex, "~> 1.0.0"},
      {:porcelain, "~> 2.0"}
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
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
