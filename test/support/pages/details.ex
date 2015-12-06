defmodule Cr2016site.Pages.Details do
  use Hound.Helpers

  def proposers do
    visible_text {:css, ".proposers"}
  end

  def mutuals do
    visible_text {:css, ".mutuals"}
  end

  def proposals_by_mutuals do
    visible_text {:css, ".proposals-by-mutuals"}
  end
end
