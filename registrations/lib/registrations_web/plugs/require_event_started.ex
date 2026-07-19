defmodule RegistrationsWeb.Plugs.RequireEventStarted do
  @moduledoc """
  Refuses gameplay actions (scanning a stake, answering a relic) until
  the current event's `start_time` has passed. The app hides the
  scanner before then, but a client that reaches the endpoint early —
  or a stale one whose clock disagrees — is turned away here so the
  server clock is the single source of truth for "has the game begun".
  """
  import Plug.Conn

  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Events
  alias Registrations.Landgrab.PlayerStrings

  def init(opts), do: opts

  def call(conn, _opts) do
    if Event.started?(Events.current(), DateTime.utc_now()) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{
        error: %{code: "not_started", detail: PlayerStrings.not_started_detail()}
      })
      |> halt()
    end
  end
end
