defmodule Cr2016site.Pages.Details do
  use Hound.Helpers

  def proposers do
    find_all_elements(:css, ".proposers tr")
    |> Enum.map(&(email_and_text_row(&1)))
  end

  def mutuals do
    find_all_elements(:css, ".mutuals tr")
    |> Enum.map(&(%{email: visible_text(find_within_element(&1, :css, ".email"))}))
  end

  def proposals_by_mutuals do
    find_all_elements(:css, ".proposals-by-mutuals tr")
    |> Enum.map(&(email_and_text_row(&1)))
  end

  def invalids do
    find_all_elements(:css, ".invalids tr")
    |> Enum.map(&(email_and_text_row(&1)))
  end

  def fill_team_emails(team_emails) do
    fill_field({:id, "team_emails"}, team_emails)
  end

  def submit do
    click({:class, "btn"})
  end

  defp email_and_text_row(row) do
    %{email: visible_text(find_within_element(row, :css, ".email")), text: visible_text(find_within_element(row, :css, ".text"))}
  end
end
