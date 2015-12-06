defmodule Cr2016site.TeamFinderTest do
  use ExUnit.Case, async: true

  alias Cr2016site.TeamFinder

  test "finds users proposing teaming up" do
    current = %{email: "A"}

    has = %{team_emails: "A"}
    has_not = %{team_emails: "C"}

    users = [has, has_not]

    assert TeamFinder.relationships(current, users).proposers == [has]
  end
end
