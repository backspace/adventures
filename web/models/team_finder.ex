defmodule Cr2016site.TeamFinder do
  def relationships(current_user, users) do
    %{proposers: Enum.filter(users, fn user -> String.contains?(user.team_emails || "", current_user.email) end)}
  end
end
