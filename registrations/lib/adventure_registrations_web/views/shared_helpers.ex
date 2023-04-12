defmodule AdventureRegistrationsWeb.SharedHelpers do
  def adventure do
    Application.get_env(:adventure_registrations, :adventure)
  end

  def phrase(id) do
    Gettext.dgettext(
      AdventureRegistrationsWeb.Gettext,
      adventure(),
      id
    )
  end

  def full_date do
    formatted_start_time("%A, %B %-d, %Y")
  end

  def short_date do
    formatted_start_time("%B %-d")
  end

  def ordinal_date do
    "#{formatted_start_time("%B")} #{AdventureRegistrations.Cldr.Number.to_string!(parsed_start_time().day, format: :ordinal)}"
  end

  def start_time do
    formatted_start_time("%-I:%M%p") |> String.downcase()
  end

  def is_unmnemonic_devices() do
    Application.get_env(:adventure_registrations, :adventure) == "unmnemonic-devices"
  end

  defp formatted_start_time(format_string) do
    Calendar.strftime(parsed_start_time(), format_string)
  end

  defp parsed_start_time do
    [raw_erl_datetime, time_zone_string] = raw_start_time()

    DateTime.from_naive!(
      NaiveDateTime.from_erl!(raw_erl_datetime),
      time_zone_string,
      Tzdata.TimeZoneDatabase
    )
  end

  defp raw_start_time do
    Application.get_env(:adventure_registrations, :start_time)
  end
end
