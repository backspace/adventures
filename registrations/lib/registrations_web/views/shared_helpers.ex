defmodule RegistrationsWeb.SharedHelpers do
  # Adapted from https://stackoverflow.com/a/42835944/760389
  def truncate(text, opts \\ []) do
    max_length = opts[:length] || 50
    omission = opts[:omission] || "…"

    cond do
      !text ->
        ""

      not String.valid?(text) ->
        text

      String.length(text) < max_length ->
        text

      true ->
        length_with_omission = max_length - String.length(omission)

        "#{String.slice(text, 0, length_with_omission)}#{omission}"
    end
  end

  def team_emails(team) do
    Enum.map(team.users, fn user -> user.email end) |> Enum.join(", ")
  end

  def adventure do
    Application.get_env(:registrations, :adventure)
  end

  def location do
    Application.get_env(:registrations, :location)
  end

  def base_url do
    Application.get_env(:registrations, :base_url)
  end

  def phrase(id) do
    Gettext.dgettext(
      RegistrationsWeb.Gettext,
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
    "#{formatted_start_time("%B")} #{Registrations.Cldr.Number.to_string!(parsed_start_time().day, format: :ordinal)}"
  end

  def start_time do
    if parsed_start_time().minute > 0 do
      formatted_start_time("%-I:%M%p") |> String.downcase()
    else
      formatted_start_time("%-I%p") |> String.downcase()
    end
  end

  def environment_protocol do
    if Mix.env() == :prod do
      "https"
    else
      "http"
    end
  end

  def is_unmnemonic_devices() do
    Application.get_env(:registrations, :adventure) == "unmnemonic-devices"
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
    Application.get_env(:registrations, :start_time)
  end
end
