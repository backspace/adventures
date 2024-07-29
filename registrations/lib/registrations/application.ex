defmodule Registrations.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :logger.add_handler(:my_sentry_handler, Sentry.LoggerHandler, %{
      config: %{metadata: [:file, :line]}
    })

    children = [
      # Start the Ecto repository
      Registrations.Repo,
      # Start the Telemetry supervisor
      RegistrationsWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Registrations.PubSub},
      # Start the Endpoint (http/https)
      RegistrationsWeb.Endpoint
      # Start a worker by calling: Registrations.Worker.start_link(arg)
      # {Registrations.Worker, arg}
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
end
