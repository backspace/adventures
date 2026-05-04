defmodule Registrations.Poles.Validations.PoleValidation do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Poles.Pole
  alias Registrations.Poles.Validations.Lifecycle
  alias Registrations.Poles.Validations.PoleValidationComment

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "poles"

  schema "pole_validations" do
    field(:status, :string, default: "assigned")
    field(:overall_notes, :string)

    belongs_to(:pole, Pole, type: :binary_id)
    belongs_to(:validator, RegistrationsWeb.User, type: :binary_id, foreign_key: :validator_id)

    belongs_to(:assigned_by, RegistrationsWeb.User,
      type: :binary_id,
      foreign_key: :assigned_by_id
    )

    has_many(:comments, PoleValidationComment, on_delete: :delete_all)

    timestamps()
  end

  @doc false
  def changeset(validation, attrs) do
    validation
    |> cast(attrs, [:pole_id, :validator_id, :assigned_by_id, :status, :overall_notes])
    |> validate_required([:pole_id, :validator_id, :assigned_by_id])
    |> validate_inclusion(:status, Lifecycle.valid_statuses())
    |> assoc_constraint(:pole)
    |> assoc_constraint(:validator)
    |> assoc_constraint(:assigned_by)
    |> validate_not_self()
  end

  defp validate_not_self(changeset) do
    pole_id = get_field(changeset, :pole_id)
    validator_id = get_field(changeset, :validator_id)

    cond do
      is_nil(pole_id) or is_nil(validator_id) ->
        changeset

      true ->
        case Registrations.Repo.get(Pole, pole_id) do
          %Pole{creator_id: ^validator_id} ->
            add_error(changeset, :validator_id, "cannot validate your own pole")

          _ ->
            changeset
        end
    end
  end
end
