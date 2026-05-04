defmodule Registrations.Poles.Validations.PuzzletValidation do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Poles.Puzzlet
  alias Registrations.Poles.Validations.Lifecycle
  alias Registrations.Poles.Validations.PuzzletValidationComment

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "poles"

  schema "puzzlet_validations" do
    field(:status, :string, default: "assigned")
    field(:overall_notes, :string)

    belongs_to(:puzzlet, Puzzlet, type: :binary_id)
    belongs_to(:validator, RegistrationsWeb.User, type: :binary_id, foreign_key: :validator_id)

    belongs_to(:assigned_by, RegistrationsWeb.User,
      type: :binary_id,
      foreign_key: :assigned_by_id
    )

    has_many(:comments, PuzzletValidationComment, on_delete: :delete_all)

    timestamps()
  end

  @doc false
  def changeset(validation, attrs) do
    validation
    |> cast(attrs, [:puzzlet_id, :validator_id, :assigned_by_id, :status, :overall_notes])
    |> validate_required([:puzzlet_id, :validator_id, :assigned_by_id])
    |> validate_inclusion(:status, Lifecycle.valid_statuses())
    |> assoc_constraint(:puzzlet)
    |> assoc_constraint(:validator)
    |> assoc_constraint(:assigned_by)
    |> validate_not_self()
  end

  defp validate_not_self(changeset) do
    puzzlet_id = get_field(changeset, :puzzlet_id)
    validator_id = get_field(changeset, :validator_id)

    cond do
      is_nil(puzzlet_id) or is_nil(validator_id) ->
        changeset

      true ->
        case Registrations.Repo.get(Puzzlet, puzzlet_id) do
          %Puzzlet{creator_id: ^validator_id} ->
            add_error(changeset, :validator_id, "cannot validate your own puzzlet")

          _ ->
            changeset
        end
    end
  end
end
