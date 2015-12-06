defmodule Cr2016site.TeamFinder do
  def users_from_email_list(email_list, users) do
    email_list
    |> String.split
    |> Enum.reduce([], fn(email, acc) ->
      user = Enum.find(users, fn(user) -> user.email == email end)
      acc ++ if user, do: [user], else: []
    end)
  end

  def relationships(current_user, users) do
    users_with_current = Enum.filter(users, fn user -> String.contains?(user.team_emails || "", current_user.email) end)
    {mutuals, proposers} = Enum.partition(users_with_current, fn user -> String.contains?(current_user.team_emails || "", user.email) end)

    proposals_by_mutuals = Enum.reduce(mutuals, %{}, fn(user, acc) ->
      user_proposals = users_from_email_list(user.team_emails, users)
      not_mutuals = (user_proposals -- mutuals) -- [current_user]

      counts_for_this_user = Enum.map(not_mutuals, fn(not_mutual) -> {not_mutual, 1} end)
      |> Enum.into(%{})

      merged = Map.merge(counts_for_this_user, acc, fn(_key, c1, c2) -> c1 + c2 end)

      merged
    end)

    %{proposers: proposers, mutuals: mutuals, proposals_by_mutuals: proposals_by_mutuals}
  end
end
