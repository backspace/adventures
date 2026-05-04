defmodule Registrations.Poles.Validations.PuzzletValidationTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Poles.Validations.PuzzletValidation
  alias Registrations.Poles.Validations.PuzzletValidationComment

  describe "PuzzletValidation.changeset" do
    test "rejects validator validating their own puzzlet" do
      author = insert(:user)
      puzzlet = insert(:puzzlet, creator: author)
      assigner = insert(:user, email: "as#{System.unique_integer([:positive])}@example.com")

      changeset =
        PuzzletValidation.changeset(%PuzzletValidation{}, %{
          puzzlet_id: puzzlet.id,
          validator_id: author.id,
          assigned_by_id: assigner.id
        })

      refute changeset.valid?
      assert "cannot validate your own puzzlet" in errors_on(changeset).validator_id
    end

    test "accepts a valid assignment" do
      author = insert(:user)
      validator = insert(:user, email: "vv#{System.unique_integer([:positive])}@example.com")
      assigner = insert(:user, email: "av#{System.unique_integer([:positive])}@example.com")
      puzzlet = insert(:puzzlet, creator: author)

      changeset =
        PuzzletValidation.changeset(%PuzzletValidation{}, %{
          puzzlet_id: puzzlet.id,
          validator_id: validator.id,
          assigned_by_id: assigner.id
        })

      assert changeset.valid?
    end
  end

  describe "PuzzletValidationComment.changeset" do
    test "accepts puzzlet-specific fields" do
      changeset =
        PuzzletValidationComment.changeset(%PuzzletValidationComment{}, %{
          puzzlet_validation_id: Ecto.UUID.generate(),
          field: "difficulty",
          suggested_value: "5"
        })

      assert changeset.valid?
    end

    test "rejects pole-only fields" do
      changeset =
        PuzzletValidationComment.changeset(%PuzzletValidationComment{}, %{
          puzzlet_validation_id: Ecto.UUID.generate(),
          field: "barcode",
          comment: "x"
        })

      assert "is invalid" in errors_on(changeset).field
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
