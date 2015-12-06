defmodule Cr2016site.TeamFinderTest do
  use ExUnit.Case, async: true

  alias Cr2016site.TeamFinder

  test "finds mutuals and users proposing teaming up" do
    current = %{email: "A", team_emails: "M1 M2"}

    mutual_one = %{email: "M1", team_emails: "A M3 M4"}
    mutual_two = %{email: "M2", team_emails: "A M3"}
    proposer = %{email: "C", team_emails: "A"}

    mutual_proposal_one = %{email: "M3", team_emails: "M1 M2"}
    mutual_proposal_two = %{email: "M4", team_emails: "M1 M2"}

    has_not = %{email: "X", team_emails: "Y"}

    users = [current, mutual_one, mutual_two, proposer, mutual_proposal_one, mutual_proposal_two, has_not]

    relationships = TeamFinder.relationships(current, users)

    assert relationships.proposers == [proposer]
    assert relationships.mutuals == [mutual_one, mutual_two]
    assert relationships.proposals_by_mutuals == Enum.into([{mutual_proposal_one, 2}, {mutual_proposal_two, 1}], %{})
  end

  test "finds users from emails" do
    user_a = %{email: "A"}
    user_b = %{email: "B"}
    user_c = %{email: "C"}

    users = [user_a, user_b, user_c]

    email_list = "A C"

    assert TeamFinder.users_from_email_list(email_list, users) == [user_a, user_c]
  end
end
