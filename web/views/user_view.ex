defmodule Cr2016site.UserView do
  use Cr2016site.Web, :view

  def proposal_by_mutual_sentence(mutuals) do
    if length(mutuals) == 1 do
      "#{hd(mutuals).email} has this address in their team emails list."
    else
      "#{Crutches.Format.List.as_sentence(Enum.map(mutuals, &(&1.email)))} have this address in their team emails lists."
    end
  end

  def class_for_attribute(u1, u2, attribute) do
    if Map.get(u1, attribute) == Map.get(u2, attribute) do
      "agreement"
    else
      "conflict"
    end
  end

  def symbol_for_attribute(u1, u2, attribute) do
    if Map.get(u1, attribute) == Map.get(u2, attribute) do
      "✓"
    else
      "✘"
    end
  end

  def risk_aversion_integer_to_string do
    %{
      1 => "Go easy on me",
      2 => "Push me a little",
      3 => "Don’t hold back"
    }
  end

  def risk_aversion_string_into_integer do
    risk_aversion_integer_to_string
    |> Map.to_list
    |> Enum.map(fn {key, value} -> {value, key} end)
    |> Enum.into(%{})
  end
end
