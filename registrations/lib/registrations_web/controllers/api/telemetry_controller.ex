defmodule RegistrationsWeb.Api.TelemetryController do
  @moduledoc """
  Lightweight app-side telemetry. The native app POSTs here on boot
  so we can answer "who has opened the app" for pre-event triage.
  Non-blocking on the app side; a failure here is silent.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Repo
  alias RegistrationsWeb.User

  def app_opened(conn, _params) do
    user = Pow.Plug.current_user(conn)

    if user do
      user
      |> Ecto.Changeset.change(last_app_open_at: DateTime.truncate(DateTime.utc_now(), :second))
      |> Repo.update()
    end

    json(conn, %{ok: true})
  end
end
