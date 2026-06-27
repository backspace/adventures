defmodule RegistrationsWeb.Landgrab.EventController do
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Events

  def show(conn, _params) do
    event = Events.current()
    now = DateTime.utc_now()

    json(conn, %{
      name: event.name,
      start_time: event.start_time,
      started: Event.started?(event, now)
    })
  end
end
