defmodule AdventureRegistrationsWeb.TeamFinderTest do
  use ExUnit.Case, async: true

  alias AdventureRegistrationsWeb.TeamFinder

  test "finds mutuals and users proposing teaming up" do
    current = %{email: "A@e.co", team_emails: "M1@e.co M2@e.co P@e.co Z@e.co XX YY"}

    mutual_one = %{email: "M1@e.co", team_emails: "A@e.co M3@e.co M4@e.co"}
    mutual_two = %{email: "M2@e.co", team_emails: "A@e.co M3@e.co"}
    proposer = %{email: "C@e.co", team_emails: "A@e.co"}

    proposee = %{email: "P@e.co", team_emails: ""}

    mutual_proposal_one = %{email: "M3@e.co", team_emails: "M1@e.co M2@e.co"}
    mutual_proposal_two = %{email: "M4@e.co", team_emails: "M1@e.co M2@e.co"}

    has_not = %{email: "X@e.co", team_emails: "Y@e.co"}

    users = [
      current,
      mutual_one,
      mutual_two,
      proposer,
      proposee,
      mutual_proposal_one,
      mutual_proposal_two,
      has_not
    ]

    relationships = TeamFinder.relationships(current, users)

    assert relationships.proposers == [proposer]
    assert relationships.mutuals == [mutual_one, mutual_two]

    assert relationships.proposals_by_mutuals ==
             Enum.into(
               [
                 {mutual_proposal_one, [mutual_one, mutual_two]},
                 {mutual_proposal_two, [mutual_one]}
               ],
               %{}
             )

    assert relationships.proposees == [%{email: proposee.email}, %{email: "Z@e.co"}]
    assert relationships.invalids == ["XX", "YY"]
    refute relationships.empty?
  end

  test "no overlap means relationships are empty" do
    current = %{email: "A@e.co", team_emails: ""}
    other = %{email: "X@e.co", team_emails: "Y@e.co"}

    users = [current, other]

    relationships = TeamFinder.relationships(current, users)

    assert relationships.empty?
  end

  test "the relationships being only mutuals is flagged" do
    current = %{email: "A@e.co", team_emails: "X@e.co"}
    mutual = %{email: "X@e.co", team_emails: "A@e.co"}

    relationships = TeamFinder.relationships(current, [current, mutual])
    assert relationships.only_mutuals?
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
