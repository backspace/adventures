defmodule RegistrationsWeb.Api.TelemetryController do
  @moduledoc """
  Lightweight app-side telemetry. The native app POSTs here on boot
  so we can answer "who has opened the app" for pre-event triage.
  Non-blocking on the app side; a failure here is silent.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Mailer
  alias Registrations.Repo

  def app_opened(conn, _params) do
    user = Pow.Plug.current_user(conn)

    if user do
      # A nil timestamp means this is the very first open — flag it for
      # an admin before we stamp it. Checked before the update so the
      # email fires exactly once, on the first open.
      first_open? = is_nil(user.last_app_open_at)

      # The client announces its build here (X-Client-Version header, e.g.
      # "1.0.0+2403"). nil for pre-telemetry clients — informative in itself.
      version = conn |> get_req_header("x-client-version") |> List.first()

      user
      |> Ecto.Changeset.change(
        last_app_open_at: DateTime.truncate(DateTime.utc_now(), :second),
        last_app_version: version
      )
      |> Repo.update()

      if first_open?, do: Mailer.app_first_opened(user)
    end

    json(conn, %{ok: true})
  end
end
