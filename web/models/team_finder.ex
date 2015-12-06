defmodule Cr2016site.TeamFinder do
  def relationships(current_user, users) do
    users_with_current = Enum.filter(users, fn user -> String.contains?(user.team_emails || "", current_user.email) end)
    {mutuals, proposers} = Enum.partition(users_with_current, fn user -> String.contains?(current_user.team_emails || "", user.email) end)

    %{proposers: proposers, mutuals: mutuals}
  end
end
