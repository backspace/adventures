defmodule Cr2016site.MessageTest do
  use Cr2016site.ModelCase

  alias Cr2016site.Message

  @valid_attrs %{
    content: "some content",
    postmarked_at: "2010-04-17",
    ready: true,
    subject: "some content"
  }
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Message.changeset(%Message{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Message.changeset(%Message{}, @invalid_attrs)
    refute changeset.valid?
  end
end
