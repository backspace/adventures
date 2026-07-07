defmodule RegistrationsWeb.SharedHelpers do
  # Adapted from https://stackoverflow.com/a/42835944/760389
  @moduledoc false
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
    team.users |> Enum.map(fn user -> user.email end) |> Enum.sort() |> Enum.join(", ")
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

  def deploy_env do
    Application.get_env(:registrations, :deploy_env, "production")
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
      "%-I:%M%p" |> formatted_start_time() |> String.downcase()
    else
      "%-I%p" |> formatted_start_time() |> String.downcase()
    end
  end

  def is_unmnemonic_devices do
    Application.get_env(:registrations, :adventure) == "unmnemonic-devices"
  end

  def is_waydowntown do
    Application.get_env(:registrations, :adventure) == "waydowntown"
  end

  def is_landgrab do
    Application.get_env(:registrations, :adventure) == "landgrab"
  end

  # Central switchboard for per-adventure feature toggles. Each
  # feature has a `default` (whether it's on when no adventure
  # override applies) and an `overrides` map keyed by adventure.
  # Skim top-to-bottom to answer "which adventures don't do X" (opt-
  # out features like risk_aversion) or "which adventures uniquely
  # do Y" (opt-in features like sender_presets).
  #
  # Kept as a plain module attribute (not Application config) so the
  # shape is discoverable in code — one place, greppable.
  #
  # For adventure-specific *content* (e.g. the accessibility-tags
  # picker whose copy only exists in landgrab's gettext), keep using
  # `is_landgrab/0` and its siblings — a feature flag needs matching
  # data in every opted-in adventure to be meaningful.
  @features %{
    risk_aversion: %{default: true, overrides: %{"landgrab" => false}},
    sender_presets: %{default: false, overrides: %{"landgrab" => true}}
  }

  def feature_enabled?(feature) do
    spec = Map.fetch!(@features, feature)
    Map.get(spec.overrides, adventure(), spec.default)
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
