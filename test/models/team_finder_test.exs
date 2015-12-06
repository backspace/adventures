defmodule Cr2016site.TeamFinderTest do
  use ExUnit.Case, async: true

  alias Cr2016site.TeamFinder

  test "finds mutuals and users proposing teaming up" do
    current = %{email: "A", team_emails: "B"}

    mutual = %{email: "B", team_emails: "A"}
    proposer = %{email: "C", team_emails: "A"}

    has_not = %{email: "X", team_emails: "Y"}

    users = [mutual, proposer, has_not]

    relationships = TeamFinder.relationships(current, users)

    assert relationships.proposers == [proposer]
    assert relationships.mutuals == [mutual]
  end
end
