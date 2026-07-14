defmodule RegistrationsWeb.LandgrabEventController do
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Events
  alias RegistrationsWeb.SharedHelpers

  plug RegistrationsWeb.Plugs.Admin

  def edit(conn, _params) do
    event = Events.current()
    render(conn, "edit.html", event: event, changeset: Event.changeset(event, %{}))
  end

  def update(conn, %{"event" => attrs}) do
    event = Events.current()

    case Events.update(event, localize_start_time(attrs)) do
      {:ok, _event} ->
        conn
        |> put_flash(:info, "Event updated.")
        |> redirect(to: Routes.landgrab_event_path(conn, :edit))

      {:error, changeset} ->
        render(conn, "edit.html", event: event, changeset: changeset)
    end
  end

  @datetime_params ~w(start_time endgame_starts_at endgame_ends_at)

  @doc """
  The datetime-local inputs post naive local times in the event's
  timezone (START_TIMEZONE); the schema stores UTC. An unparseable
  value passes through untouched so the changeset reports the error.
  Public so the conversion is testable without an admin session.
  """
  def localize_start_time(attrs) do
    Enum.reduce(@datetime_params, attrs, &localize_param/2)
  end

  defp localize_param(param, attrs) do
    case attrs do
      %{^param => value} when is_binary(value) and value != "" ->
        with {:ok, naive} <- NaiveDateTime.from_iso8601(pad_seconds(value)),
             {:ok, local} <- DateTime.from_naive(naive, SharedHelpers.start_timezone(), Tzdata.TimeZoneDatabase) do
          Map.put(attrs, param, DateTime.shift_zone!(local, "Etc/UTC", Tzdata.TimeZoneDatabase))
        else
          # DST fall-back repeats an hour; take its first occurrence.
          {:ambiguous, first, _second} ->
            Map.put(attrs, param, DateTime.shift_zone!(first, "Etc/UTC", Tzdata.TimeZoneDatabase))

          # DST spring-forward skips the entry entirely; land just after.
          {:gap, _just_before, just_after} ->
            Map.put(attrs, param, DateTime.shift_zone!(just_after, "Etc/UTC", Tzdata.TimeZoneDatabase))

          _ ->
            attrs
        end

      _ ->
        attrs
    end
  end

  # datetime-local omits seconds unless the user typed them.
  defp pad_seconds(value) when byte_size(value) == 16, do: value <> ":00"
  defp pad_seconds(value), do: value
end
