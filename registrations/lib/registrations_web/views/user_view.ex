defmodule RegistrationsWeb.UserView do
  use RegistrationsWeb, :view

  def proposal_by_mutual_sentence(mutuals) do
    if length(mutuals) == 1 do
      "#{hd(mutuals).email} has this address in their team emails list."
    else
      "#{Registrations.Cldr.List.to_string!(Enum.map(mutuals, & &1.email))} have this address in their team emails lists."
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

  def symbol_for_boolean(value) do
    case value do
      true -> "✓"
      false -> "✘"
      _ -> "?"
    end
  end

  def risk_aversion_integer_to_string() do
    %{
      1 => phrase("risk_aversion_label_1"),
      2 => phrase("risk_aversion_label_2"),
      3 => phrase("risk_aversion_label_3")
    }
  end

  def risk_aversion_string_into_integer do
    risk_aversion_integer_to_string()
    |> Map.to_list()
    |> Enum.map(fn {key, value} -> {value, key} end)
    |> Enum.into(%{})
  end

  def is_empty?(user) do
    String.trim(user.team_emails || "") == "" &&
      !Enum.member?([1, 2, 3], user.risk_aversion) &&
      String.trim(user.proposed_team_name || "") == "" &&
      String.trim(user.accessibility || "") == "" &&
      String.trim(user.comments || "") == "" &&
      String.trim(user.source || "") == ""
  end
end
