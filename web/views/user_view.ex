defmodule Cr2016site.UserView do
  use Cr2016site.Web, :view

  def proposal_by_mutual_sentence(mutuals) do
    if length(mutuals) == 1 do
      "#{hd(mutuals).email} has this address in their team emails list."
    else
      "#{Crutches.Format.List.as_sentence(Enum.map(mutuals, &(&1.email)))} have this address in their team emails lists."
    end
  end
end
