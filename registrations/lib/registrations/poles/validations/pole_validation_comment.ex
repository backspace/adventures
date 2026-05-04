defmodule Registrations.Poles.Validations.PoleValidationComment do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Poles.Validations.PoleValidation

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "poles"

  @valid_fields ~w(barcode label latitude longitude notes)
  @valid_statuses ~w(pending accepted rejected)

  schema "pole_validation_comments" do
    field(:field, :string)
    field(:comment, :string)
    field(:suggested_value, :string)
    field(:status, :string, default: "pending")

    belongs_to(:pole_validation, PoleValidation, type: :binary_id)

    timestamps()
  end

  def valid_fields, do: @valid_fields
  def valid_statuses, do: @valid_statuses

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:pole_validation_id, :field, :comment, :suggested_value, :status])
    |> validate_required([:pole_validation_id, :field])
    |> validate_inclusion(:field, @valid_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_has_content()
    |> assoc_constraint(:pole_validation)
  end

  defp validate_has_content(changeset) do
    if get_field(changeset, :comment) || get_field(changeset, :suggested_value) do
      changeset
    else
      add_error(changeset, :comment, "at least one of comment or suggested_value is required")
    end
  end
end
