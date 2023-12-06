defmodule AdventureRegistrationsWeb.TeamTest do
  use AdventureRegistrations.ModelCase

  alias AdventureRegistrationsWeb.Team

  @valid_attrs %{name: "some content", notes: "some content", risk_aversion: 42}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Team.changeset(%Team{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Team.changeset(%Team{}, @invalid_attrs)
    refute changeset.valid?
  end
end
