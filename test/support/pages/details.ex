defmodule Cr2016site.Pages.Details do
  use Hound.Helpers

  def proposers do
    visible_text {:css, ".proposers"}
  end

  def mutuals do
    visible_text {:css, ".mutuals"}
  end
end
