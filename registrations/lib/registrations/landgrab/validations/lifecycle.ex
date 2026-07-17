defmodule Registrations.Landgrab.Validations.Lifecycle do
  @moduledoc """
  Shared status transition rules for pole and puzzlet validations.

  Lifecycle:

      assigned ──validator──► in_progress ──validator──► submitted
         │                         │                        │
         │       ┌─────────────────┘         supervisor ────┤
         └───────┴──validator──► unfindable                 ├──► accepted
                                     │                       └──► rejected
                        supervisor ──┴──► accepted | rejected

  `submitted` is reachable directly from `assigned` too: the new
  validator form is a single submit, so it needn't step through
  `in_progress` first. `unfindable` is a validator outcome for a pole
  they couldn't locate; the supervisor resolves it (accept ⇒ retire the
  pole, reject ⇒ send back to draft).
  """

  import Ecto.Changeset

  @valid_statuses ~w(assigned in_progress submitted accepted rejected unfindable)

  @validator_transitions %{
    "assigned" => ["in_progress", "submitted", "unfindable"],
    "in_progress" => ["submitted", "unfindable"]
  }

  @supervisor_transitions %{
    "submitted" => ["accepted", "rejected"],
    "unfindable" => ["accepted", "rejected"]
  }

  def valid_statuses, do: @valid_statuses

  @doc """
  Validates a status transition for the given role (`:validator` or
  `:supervisor`). Adds a changeset error if the transition isn't allowed.
  """
  def validate_status_transition(changeset, current_status, role) do
    case get_change(changeset, :status) do
      nil ->
        changeset

      new_status ->
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
    end
  end
end
