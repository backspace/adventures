defmodule RegistrationsWeb.Api.TelemetryController do
  @moduledoc """
  Lightweight app-side telemetry. The native app POSTs here on boot
  so we can answer "who has opened the app" for pre-event triage.
  Non-blocking on the app side; a failure here is silent.
  """
  use RegistrationsWeb, :controller

  require Logger

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

      # Auto-track the newest build seen (per platform, since iOS/Android
      # number independently) so the app can warn older clients without any
      # hand-maintained version numbers. Landgrab-only; harmless no-op data.
      note_client_build(conn, version)

      if first_open?, do: Mailer.app_first_opened(user)
    end

    json(conn, %{ok: true})
  end

  # Ratchet the newest-build-seen for this client's platform onto the current
  # landgrab event. The platform comes from the X-Client-Platform header; the
  # build is the integer after "+" in the version string ("1.0.0+2403" → 2403).
  # Only meaningful for the landgrab adventure.
  defp note_client_build(conn, version) do
    if Application.get_env(:registrations, :adventure) == "landgrab" do
      platform = conn |> get_req_header("x-client-platform") |> List.first()

      # TEMPORARY diagnostic: log every ping's platform + build + who sent it,
      # to trace which client is populating latest_build_android. Remove once
      # the stray Android ping is identified. Grep logs for TELEMETRY-PLATFORM.
      user = Pow.Plug.current_user(conn)

      Logger.info(
        "[TELEMETRY-PLATFORM] platform=#{inspect(platform)} version=#{inspect(version)} " <>
          "build=#{inspect(build_number(version))} user=#{inspect(user && user.email)}"
      )

      case build_number(version) do
        nil -> :ok
        build -> Registrations.Landgrab.note_client_build(platform, build)
      end
    end
  end

  defp build_number(nil), do: nil

  defp build_number(version) do
    case version |> String.split("+") |> List.last() |> Integer.parse() do
      {n, _} when n > 0 -> n
      _ -> nil
    end
  end
end
