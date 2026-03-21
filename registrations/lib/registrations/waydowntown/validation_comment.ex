defmodule Registrations.Waydowntown.ValidationComment do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  @valid_fields ~w(answer label hint start_description task_description)

  @valid_statuses ~w(pending accepted rejected)

  schema "validation_comments" do
    field(:field, :string)
    field(:comment, :string)
    field(:suggested_value, :string)
    field(:status, :string, default: "pending")

    belongs_to(:specification_validation, Registrations.Waydowntown.SpecificationValidation, type: :binary_id)
    belongs_to(:answer, Registrations.Waydowntown.Answer, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:specification_validation_id, :answer_id, :field, :comment, :suggested_value, :status])
    |> validate_required([:specification_validation_id])
    |> validate_inclusion(:field, @valid_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_has_content()
    |> assoc_constraint(:specification_validation)
  end

  defp validate_has_content(changeset) do
    comment = get_field(changeset, :comment)
    suggested_value = get_field(changeset, :suggested_value)

    if is_nil(comment) and is_nil(suggested_value) do
      add_error(changeset, :comment, "at least one of comment or suggested_value is required")
    else
      changeset
    end
  end
end
