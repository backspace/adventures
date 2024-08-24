defmodule RegistrationsWeb.TeamFinderTest do
  use ExUnit.Case, async: true

  alias RegistrationsWeb.TeamFinder

  test "finds mutuals and users proposing teaming up" do
    current = %{
      id: "A",
      email: "A@e.co",
      team_emails: "M1@e.co M2@e.co PU@e.co PI@e.co Z@e.co XX YY"
    }

    mutual_one = %{id: "M1", email: "M1@e.co", team_emails: "A@e.co M3@e.co M4@e.co"}
    mutual_two = %{id: "M2", email: "M2@e.co", team_emails: "A@e.co M3@e.co"}
    proposer = %{id: "C", email: "C@e.co", team_emails: "A@e.co"}

    proposee_uninvited = %{id: "PU", email: "PU@e.co", team_emails: "", invited_by_id: nil}
    proposee_invited = %{id: "PI", email: "PI@e.co", team_emails: "", invited_by_id: "A"}

    mutual_proposal_one = %{id: "M3", email: "M3@e.co", team_emails: "M1@e.co M2@e.co"}
    mutual_proposal_two = %{id: "M4", email: "M4@e.co", team_emails: "M1@e.co M2@e.co"}

    has_not = %{id: "X", email: "X@e.co", team_emails: "Y@e.co"}

    users = [
      current,
      mutual_one,
      mutual_two,
      proposer,
      proposee_uninvited,
      proposee_invited,
      mutual_proposal_one,
      mutual_proposal_two,
      has_not
    ]

    relationships = TeamFinder.relationships(current, users)

    assert relationships.proposers == [proposer]
    assert relationships.mutuals == [mutual_one, mutual_two]

    assert relationships.proposals_by_mutuals ==
             Map.new([
               {mutual_proposal_one, [mutual_one, mutual_two]},
               {mutual_proposal_two, [mutual_one]}
             ])

    assert relationships.proposees == [
             %{email: proposee_uninvited.email, invited: false},
             %{email: proposee_invited.email, invited: true},
             %{email: "Z@e.co", invited: false}
           ]

    assert relationships.invalids == ["XX", "YY"]
    refute relationships.empty?
  end

  test "no overlap means relationships are empty" do
    current = %{id: "A", email: "A@e.co", team_emails: ""}
    other = %{id: "X", email: "X@e.co", team_emails: "Y@e.co"}

    users = [current, other]

    relationships = TeamFinder.relationships(current, users)

    assert relationships.empty?
  end

  test "the relationships being only mutuals is flagged" do
    current = %{id: "A", email: "A@e.co", team_emails: "X@e.co"}
    mutual = %{id: "X", email: "X@e.co", team_emails: "A@e.co"}

    relationships = TeamFinder.relationships(current, [current, mutual])
    assert relationships.only_mutuals?
  end

  test "finds users from emails" do
    user_a = %{id: "A", email: "A"}
    user_b = %{id: "B", email: "B"}
    user_c = %{id: "C", email: "C"}

    users = [user_a, user_b, user_c]

    email_list = "A C"

    assert TeamFinder.users_from_email_list(email_list, users) == [user_a, user_c]
  end
end
