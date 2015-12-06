defmodule Cr2016site.Pages.Details do
  use Hound.Helpers

  def proposers do
    visible_text {:css, ".proposers"}
  end

  def mutuals do
    find_all_elements(:css, ".mutuals tr")
    |> Enum.map(&(%{email: visible_text(find_within_element(&1, :css, ".email"))}))
  end

  def proposals_by_mutuals do
    find_all_elements(:css, ".proposals-by-mutuals li")
    |> Enum.map(&(visible_text(&1)))
  end
end
