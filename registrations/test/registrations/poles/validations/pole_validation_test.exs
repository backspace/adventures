defmodule Registrations.Poles.Validations.PoleValidationTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Poles.Validations.Lifecycle
  alias Registrations.Poles.Validations.PoleValidation
  alias Registrations.Poles.Validations.PoleValidationComment

  describe "PoleValidation.changeset" do
    test "requires the three FKs" do
      changeset = PoleValidation.changeset(%PoleValidation{}, %{})
      refute changeset.valid?

      assert "can't be blank" in errors_on(changeset).pole_id
      assert "can't be blank" in errors_on(changeset).validator_id
      assert "can't be blank" in errors_on(changeset).assigned_by_id
    end

    test "rejects validator validating their own pole" do
      author = insert(:user)
      pole = insert(:pole, creator: author, status: :draft)
      assigner = insert(:user)

      changeset =
        PoleValidation.changeset(%PoleValidation{}, %{
          pole_id: pole.id,
          validator_id: author.id,
          assigned_by_id: assigner.id
        })

      refute changeset.valid?
      assert "cannot validate your own pole" in errors_on(changeset).validator_id
    end

    test "accepts a valid assignment" do
      author = insert(:user)
      validator = insert(:user, email: "v#{System.unique_integer([:positive])}@example.com")
      assigner = insert(:user, email: "a#{System.unique_integer([:positive])}@example.com")
      pole = insert(:pole, creator: author, status: :draft)

      changeset =
        PoleValidation.changeset(%PoleValidation{}, %{
          pole_id: pole.id,
          validator_id: validator.id,
          assigned_by_id: assigner.id
        })

      assert changeset.valid?
    end

    test "rejects unknown statuses" do
      changeset =
        PoleValidation.changeset(%PoleValidation{}, %{
          pole_id: Ecto.UUID.generate(),
          validator_id: Ecto.UUID.generate(),
          assigned_by_id: Ecto.UUID.generate(),
          status: "frobnicated"
        })

      assert "is invalid" in errors_on(changeset).status
    end
  end

  describe "Lifecycle.validate_status_transition" do
    test "validator can move assigned → in_progress" do
      changeset =
        %PoleValidation{status: "assigned"}
        |> Ecto.Changeset.change(status: "in_progress")
        |> Lifecycle.validate_status_transition("assigned", :validator)

      assert changeset.valid?
    end

    test "validator cannot accept" do
      changeset =
        %PoleValidation{status: "submitted"}
        |> Ecto.Changeset.change(status: "accepted")
        |> Lifecycle.validate_status_transition("submitted", :validator)

      refute changeset.valid?
      assert errors_on(changeset).status |> Enum.any?(&String.contains?(&1, "cannot transition"))
    end

    test "supervisor can accept submitted" do
      changeset =
        %PoleValidation{status: "submitted"}
        |> Ecto.Changeset.change(status: "accepted")
        |> Lifecycle.validate_status_transition("submitted", :supervisor)

      assert changeset.valid?
    end

    test "supervisor cannot move assigned forward (validator's job)" do
      changeset =
        %PoleValidation{status: "assigned"}
        |> Ecto.Changeset.change(status: "in_progress")
        |> Lifecycle.validate_status_transition("assigned", :supervisor)

      refute changeset.valid?
    end
  end

  describe "PoleValidationComment.changeset" do
    test "rejects unknown fields" do
      changeset =
        PoleValidationComment.changeset(%PoleValidationComment{}, %{
          pole_validation_id: Ecto.UUID.generate(),
          field: "garbage",
          comment: "x"
        })

      assert "is invalid" in errors_on(changeset).field
    end

    test "requires comment or suggested_value" do
      changeset =
        PoleValidationComment.changeset(%PoleValidationComment{}, %{
          pole_validation_id: Ecto.UUID.generate(),
          field: "label"
        })

      assert errors_on(changeset).comment |> Enum.any?(&String.contains?(&1, "required"))
    end

    test "accepts a comment-only entry" do
      changeset =
        PoleValidationComment.changeset(%PoleValidationComment{}, %{
          pole_validation_id: Ecto.UUID.generate(),
          field: "label",
          comment: "this seems off"
        })

      assert changeset.valid?
    end

    test "accepts a suggested_value-only entry" do
      changeset =
        PoleValidationComment.changeset(%PoleValidationComment{}, %{
          pole_validation_id: Ecto.UUID.generate(),
          field: "barcode",
          suggested_value: "POLE-007"
        })

      assert changeset.valid?
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
