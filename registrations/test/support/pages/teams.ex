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

  # ──────── Edit page: member management ─────────────────────────────

  def has_member?(session, email) do
    Browser.has?(session, Query.css("[data-test-member='#{email}']"))
  end

  # Pick the person from the grouped dropdown (labelled "Add member"; option
  # labels are emails), then submit.
  def add_member(session, email) do
    session
    |> Browser.find(Query.select("Add member"))
    |> Browser.click(Query.option(email))

    Browser.click(session, Query.button("Add member"))
  end

  def remove_member(session, email) do
    Browser.click(session, Query.css("[data-test-member='#{email}'] .remove-member"))
  end
end
