defmodule Registrations.Waydowntown.SpecificationTest do
  use Registrations.DataCase

  alias Registrations.Waydowntown.Specification

  describe "changeset/2" do
    test "validates required fields" do
      changeset = Specification.changeset(%Specification{}, %{})
      assert "can't be blank" in errors_on(changeset).concept
      assert "can't be blank" in errors_on(changeset).task_description
    end

    test "validates concept" do
      valid_concepts = ["bluetooth_collector", "payphone_collector", "elevator_collector"]
      invalid_concept = "invalid_concept"

      Enum.each(valid_concepts, fn concept ->
        valid_changeset = Specification.changeset(%Specification{}, %{concept: concept, task_description: "test"})
        assert valid_changeset.valid?
      end)

      invalid_changeset = Specification.changeset(%Specification{}, %{concept: invalid_concept, task_description: "test"})

      refute invalid_changeset.valid?
      assert "must be a known concept" in errors_on(invalid_changeset).concept
    end

    test "validates duration" do
      changeset =
        Specification.changeset(%Specification{}, %{
          concept: "bluetooth_collector",
          task_description: "test",
          duration: -1
        })

      assert "must be greater than 0" in errors_on(changeset).duration

      changeset =
        Specification.changeset(%Specification{}, %{concept: "bluetooth_collector", task_description: "test", duration: 0})

      assert "must be greater than 0" in errors_on(changeset).duration

      changeset =
        Specification.changeset(%Specification{}, %{
          concept: "bluetooth_collector",
          task_description: "test",
          duration: nil
        })

      assert changeset.valid?
    end
  end
end
