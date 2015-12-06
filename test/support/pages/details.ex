defmodule Cr2016site.Pages.Details do
  use Hound.Helpers

  def proposers do
    visible_text {:css, ".proposers"}
  end

  def mutuals do
    find_all_elements(:css, ".mutuals li")
    |> Enum.map(fn(e) -> visible_text(e) end)
  end

  def proposals_by_mutuals do
    visible_text {:css, ".proposals-by-mutuals"}
  end
end
