defmodule Cr2016site.TeamTest do
  use Cr2016site.ModelCase

  alias Cr2016site.Team

  @valid_attrs %{name: "some content", notes: "some content", risk_aversion: 42, user_ids: []}
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
