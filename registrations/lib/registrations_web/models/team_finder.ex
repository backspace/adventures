defmodule RegistrationsWeb.TeamFinder do
  @moduledoc false
  def users_from_email_list(email_list, users) do
    email_list
    |> String.split()
    |> Enum.reduce([], fn email, acc ->
      user = Enum.find(users, fn user -> user.email == email end)
      acc ++ if user, do: [user], else: []
    end)
  end

  def relationships(current_user, users) do
    users_with_current =
      Enum.filter(users, fn user ->
        String.contains?(user.team_emails || "", current_user.email)
      end)

    {mutuals, proposers} =
      Enum.split_with(users_with_current, fn user ->
        String.contains?(current_user.team_emails || "", user.email)
      end)

    proposals_by_mutuals =
      Enum.reduce(mutuals, %{}, fn user, acc ->
        user_proposals = users_from_email_list(user.team_emails, users)
        not_mutuals = (user_proposals -- mutuals) -- [current_user]

        proposers_for_this_mutual =
          Map.new(not_mutuals, fn not_mutual -> {not_mutual, [user]} end)

        merged = Map.merge(proposers_for_this_mutual, acc, fn _key, c1, c2 -> c2 ++ c1 end)

        merged
      end)

    emails = String.split(current_user.team_emails || "")

    invalids =
      Enum.reject(emails, fn string ->
        Regex.match?(~r/^\s*([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\s*$/i, string)
      end)

    proposees =
      Enum.map((emails -- invalids) -- Enum.map(users_with_current, & &1.email), fn email ->
        registered_user = Enum.find(users, fn user -> user.email == email end)

        case registered_user do
          nil -> %{email: email, invited: false}
          _ -> %{email: email, invited: registered_user.invited_by_id == current_user.id}
        end
      end)

    empty =
      Enum.all?([proposers, mutuals, proposals_by_mutuals, invalids, proposees], fn collection ->
        Enum.empty?(collection)
      end)

    only_mutuals =
      Enum.all?([proposers, proposals_by_mutuals, invalids, proposees], fn collection ->
        Enum.empty?(collection)
      end)

    %{
      proposers: proposers,
      mutuals: mutuals,
      proposals_by_mutuals: proposals_by_mutuals,
      invalids: invalids,
      proposees: proposees,
      empty?: empty,
      only_mutuals?: only_mutuals
    }
  end
end
