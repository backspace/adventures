defmodule Registrations.Pages.Teams do
  @moduledoc false
  alias Wallaby.Browser
  alias Wallaby.Query

  defp team_container(index) do
    "tbody tr:nth-child(#{index})"
  end

  def name(session, index) do
    Browser.text(session, Query.css("#{team_container(index)} .name"))
  end

  def risk_aversion(session, index) do
    Browser.text(session, Query.css("#{team_container(index)} .risk-aversion"))
  end

  def emails(session, index) do
    Browser.text(session, Query.css("#{team_container(index)} [data-test-emails]"))
  end
end
