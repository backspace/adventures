defmodule Registrations.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    :logger.add_handler(:my_sentry_handler, Sentry.LoggerHandler, %{
      config: %{metadata: [:file, :line]}
    })

    set_premailex_ssl_options()

    # Without this the GameController filter produces this error: not an already existing atom
    specification_concept_hack = String.to_atom("specification.concept")
    specification_id_hack = String.to_atom("specification.id")
    specification_placed_hack = String.to_atom("specification.placed")
    specification_position_hack = String.to_atom("specification.position")

    Logger.info("Hack: #{inspect(specification_concept_hack)}")
    Logger.info("Hack: #{inspect(specification_id_hack)}")
    Logger.info("Hack: #{inspect(specification_placed_hack)}")
    Logger.info("Hack: #{inspect(specification_position_hack)}")

    children = [
      # Start the Ecto repository
      Registrations.Repo,
      # Start the Telemetry supervisor
      RegistrationsWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Registrations.PubSub},
      # Start the Endpoint (http/https)
      RegistrationsWeb.Endpoint,
      # Start a worker by calling: Registrations.Worker.start_link(arg)
      # {Registrations.Worker, arg}
      {ConCache, [name: :registrations_cache, ttl_check_interval: false]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Registrations.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RegistrationsWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # https://github.com/danschultzer/premailex/issues/87#issuecomment-2635517602
  defp set_premailex_ssl_options do
    Application.put_env(
      :premailex,
      :http_adapter,
      {Premailex.HTTPAdapter.Httpc,
       [
         ssl: [
           verify: :verify_peer,
           cacerts: :public_key.cacerts_get(),
           depth: 3,
           customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
         ]
       ]}
    )
  end
end
