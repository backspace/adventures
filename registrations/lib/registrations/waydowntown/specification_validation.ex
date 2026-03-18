defmodule Registrations.Waydowntown.SpecificationValidation do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  @valid_statuses ~w(assigned in_progress submitted accepted rejected)
  @validator_transitions %{
    "assigned" => ["in_progress"],
    "in_progress" => ["submitted"]
  }
  @supervisor_transitions %{
    "submitted" => ["accepted", "rejected"]
  }

  schema "specification_validations" do
    field(:status, :string, default: "assigned")
    field(:play_mode, :string)
    field(:overall_notes, :string)

    belongs_to(:specification, Registrations.Waydowntown.Specification, type: :binary_id)
    belongs_to(:validator, RegistrationsWeb.User, type: :binary_id, foreign_key: :validator_id)
    belongs_to(:assigned_by, RegistrationsWeb.User, type: :binary_id, foreign_key: :assigned_by_id)
    belongs_to(:run, Registrations.Waydowntown.Run, type: :binary_id)

    has_many(:validation_comments, Registrations.Waydowntown.ValidationComment, on_delete: :delete_all)

    timestamps()
  end

  @doc false
  def changeset(validation, attrs) do
    validation
    |> cast(attrs, [:specification_id, :validator_id, :assigned_by_id, :status, :play_mode, :overall_notes, :run_id])
    |> validate_required([:specification_id, :validator_id, :assigned_by_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:play_mode, ~w(blind with_answers), message: "must be 'blind' or 'with_answers'")
    |> unique_constraint([:specification_id, :validator_id])
    |> assoc_constraint(:specification)
  end

  def validate_status_transition(changeset, current_status, role) do
    new_status = get_change(changeset, :status)

    if new_status do
      transitions =
        case role do
          :validator -> @validator_transitions
          :supervisor -> @supervisor_transitions
        end

      allowed = Map.get(transitions, current_status, [])

      if new_status in allowed do
        changeset
      else
        add_error(changeset, :status, "cannot transition from '#{current_status}' to '#{new_status}'")
      end
    else
      changeset
    end
  end

  def valid_statuses, do: @valid_statuses
end
