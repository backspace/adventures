defmodule Cr2016site.Pages.Details do
  use Hound.Helpers

  def proposers do
    find_all_elements(:css, ".proposers tr")
    |> Enum.map(&(email_and_text_row(&1)))
  end

  def mutuals do
    find_all_elements(:css, ".mutuals tr")
    |> Enum.map(fn(row) ->
      proposed_team_name_element = find_within_element(row, :css, ".proposed-team-name")
      %{
        email: visible_text(find_within_element(row, :css, ".email")),
        symbol: visible_text(find_within_element(row, :css, ".symbol")),
        proposed_team_name: %{
          value: visible_text(proposed_team_name_element),
          conflict?: String.contains?(attribute_value(proposed_team_name_element, "class"), "conflict"),
          agreement?: String.contains?(attribute_value(proposed_team_name_element, "class"), "agreement")
        }
      }
    end)
  end

  def proposals_by_mutuals do
    find_all_elements(:css, ".proposals-by-mutuals tr")
    |> Enum.map(&(email_and_text_row(&1)))
  end

  def invalids do
    find_all_elements(:css, ".invalids tr")
    |> Enum.map(&(email_and_text_row(&1)))
  end

  def proposees do
    find_all_elements(:css, ".proposees tr")
    |> Enum.map(&(email_and_text_row(&1)))
  end

  def fill_team_emails(team_emails) do
    fill_field({:id, "team-emails"}, team_emails)
  end

  def fill_proposed_team_name(proposed_team_name) do
    fill_field({:id, "proposed-team-name"}, proposed_team_name)
  end

  def submit do
    click({:class, "btn"})
  end

  defp email_and_text_row(row) do
    %{
      email: visible_text(find_within_element(row, :css, ".email")),
      symbol: visible_text(find_within_element(row, :css, ".symbol")),
      text: visible_text(find_within_element(row, :css, ".text")),
      add: fn -> click(find_within_element(row, :css, "a")) end
    }
  end
end
