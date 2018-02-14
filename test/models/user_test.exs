defmodule Cr2016site.UserTest do
  use Cr2016site.ModelCase

  alias Cr2016site.User

  import Mock

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

  test "details changeset without a new phone number doesn’t have a confirmation" do
    changeset = User.details_changeset(%User{txt: true, number: "2045551212"}, %{source: "something"})
    assert changeset.valid?
    refute Ecto.Changeset.get_field(changeset, :txt_confirmation_sent)
  end

  test "details changeset with a new but invalid phone number doesn’t have a confirmation" do
    changeset = User.details_changeset(%User{txt: true, number: "2045551212"}, %{number: "aaaa"})
    refute changeset.valid?
    refute Ecto.Changeset.get_field(changeset, :txt_confirmation_sent)
  end

  test_with_mock "details changeset with a new phone number has a confirmation", Cr2016site.Random, [uniform: fn(999999) -> 1234 end] do
    changeset = User.details_changeset(%User{txt: true, number: "2045551212"}, %{number: "2045551313"})
    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :txt_confirmation_sent) == "001234"
  end
end
