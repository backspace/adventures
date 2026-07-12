defmodule RegistrationsWeb.LandgrabEventView do
  use RegistrationsWeb, :view

  # The event row stores UTC; the admin form works in the event's
  # local timezone (START_TIMEZONE). These helpers shift for display —
  # the reverse conversion on save happens in LandgrabEventController.

  def event_timezone, do: start_timezone()

  def local_input_value(nil), do: nil

  def local_input_value(%DateTime{} = utc) do
    utc |> to_local() |> Calendar.strftime("%Y-%m-%dT%H:%M")
  end

  def format_local(%DateTime{} = utc) do
    utc |> to_local() |> Calendar.strftime("%Y-%m-%d %H:%M %Z")
  end

  defp to_local(%DateTime{} = utc) do
    DateTime.shift_zone!(utc, event_timezone(), Tzdata.TimeZoneDatabase)
  end
end
