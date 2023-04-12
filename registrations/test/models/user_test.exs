defmodule AdventureRegistrationsWeb.UserTest do
  use AdventureRegistrations.ModelCase

  alias AdventureRegistrationsWeb.User
  import AdventureRegistrations.Factory

  @valid_attrs %{password: "some content", email: "some@content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = User.changeset(%User{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = User.changeset(%User{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "candidate voicepasses exclude ones with overlapping prefixes" do
    insert(:user, email: "empty@example.com")
    insert(:user, email: "someone@example.com", voicepass: "ureterocolostomy")
    insert(:user, email: "other@example.com", voicepass: "weatherstripping")

    candidates = User.voicepass_candidates()

    refute Enum.member?(candidates, "urethroprostatic")
    refute Enum.member?(candidates, "weatherproofness")

    assert Enum.member?(candidates, "unproductiveness")
  end
end
