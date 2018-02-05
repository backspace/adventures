defmodule Cr2016site.SharedHelpers do
  def city do
    # Not in config? Unsure…
    "Winnipeg"
  end

  def adventure_name do
    "txtbeyond"
  end

  def full_date do
    formatted_start_time("%A, %B %e, %Y")
  end

  def short_date do
    formatted_start_time("%B %e")
  end

  def ordinal_date do
    "#{formatted_start_time("%B")} #{Crutches.Format.Integer.ordinalize(parsed_start_time().day)}"
  end

  def start_time do
    formatted_start_time("%-I:%M%p") |> String.downcase()
  end

  defp formatted_start_time(format_string) do
    Timex.DateFormat.format!(parsed_start_time(), format_string, :strftime)
  end

  defp parsed_start_time do
    apply(Timex.Date, :from, raw_start_time())
  end

  defp raw_start_time do
    Application.get_env(:cr2016site, :start_time)
  end
end
