defmodule RegistrationsWeb.PolesEventController do
  use RegistrationsWeb, :controller

  alias Registrations.Poles.Event
  alias Registrations.Poles.Events

  plug RegistrationsWeb.Plugs.Admin

  def edit(conn, _params) do
    event = Events.current()
    render(conn, "edit.html", event: event, changeset: Event.changeset(event, %{}))
  end

  def update(conn, %{"event" => attrs}) do
    event = Events.current()

    case Events.update(event, attrs) do
      {:ok, _event} ->
        conn
        |> put_flash(:info, "Event updated.")
        |> redirect(to: Routes.poles_event_path(conn, :edit))

      {:error, changeset} ->
        render(conn, "edit.html", event: event, changeset: changeset)
    end
  end
end
