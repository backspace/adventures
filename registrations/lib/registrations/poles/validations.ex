defmodule Registrations.Poles.Validations do
  @moduledoc """
  Context for the validation lifecycle. Functions are split into
  assignment (supervisor), validator transitions, and comment CRUD.
  Status transitions are gated by `Registrations.Poles.Validations.Lifecycle`.
  """
  import Ecto.Query, warn: false

  alias Registrations.Poles.Pole
  alias Registrations.Poles.Puzzlet
  alias Registrations.Poles.Validations.Lifecycle
  alias Registrations.Poles.Validations.PoleValidation
  alias Registrations.Poles.Validations.PoleValidationComment
  alias Registrations.Poles.Validations.PuzzletValidation
  alias Registrations.Poles.Validations.PuzzletValidationComment
  alias Registrations.Repo

  # ──────── Assignment (supervisor entry points) ─────────────────────

  def assign_pole_validation(pole_id, validator_id, assigner_id) do
    Repo.transaction(fn ->
      changeset =
        PoleValidation.changeset(%PoleValidation{}, %{
          pole_id: pole_id,
          validator_id: validator_id,
          assigned_by_id: assigner_id,
          status: "assigned"
        })

      with {:ok, validation} <- Repo.insert(changeset),
           pole <- Repo.get!(Pole, pole_id),
           {:ok, _} <- maybe_flip_pole(pole, :in_review) do
        validation
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def assign_puzzlet_validation(puzzlet_id, validator_id, assigner_id) do
    Repo.transaction(fn ->
      changeset =
        PuzzletValidation.changeset(%PuzzletValidation{}, %{
          puzzlet_id: puzzlet_id,
          validator_id: validator_id,
          assigned_by_id: assigner_id,
          status: "assigned"
        })

      with {:ok, validation} <- Repo.insert(changeset),
           puzzlet <- Repo.get!(Puzzlet, puzzlet_id),
           {:ok, _} <- maybe_flip_puzzlet(puzzlet, :in_review) do
        validation
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp maybe_flip_pole(%Pole{status: :draft} = pole, new_status) do
    pole |> Ecto.Changeset.change(status: new_status) |> Repo.update()
  end

  defp maybe_flip_pole(pole, _), do: {:ok, pole}

  defp maybe_flip_puzzlet(%Puzzlet{status: :draft} = puzzlet, new_status) do
    puzzlet |> Ecto.Changeset.change(status: new_status) |> Repo.update()
  end

  defp maybe_flip_puzzlet(puzzlet, _), do: {:ok, puzzlet}

  # ──────── Validator queries ────────────────────────────────────────

  def list_assignments_for(validator_id) do
    pole =
      PoleValidation
      |> where([v], v.validator_id == ^validator_id)
      |> where([v], v.status not in ^["accepted", "rejected"])
      |> order_by([v], desc: v.inserted_at)
      |> Repo.all()
      |> Repo.preload([:pole, :comments])

    puzzlet =
      PuzzletValidation
      |> where([v], v.validator_id == ^validator_id)
      |> where([v], v.status not in ^["accepted", "rejected"])
      |> order_by([v], desc: v.inserted_at)
      |> Repo.all()
      |> Repo.preload([:puzzlet, :comments])

    %{pole_validations: pole, puzzlet_validations: puzzlet}
  end

  def get_pole_validation(id), do: Repo.get(PoleValidation, id) |> preload_pole_validation()
  def get_puzzlet_validation(id), do: Repo.get(PuzzletValidation, id) |> preload_puzzlet_validation()

  defp preload_pole_validation(nil), do: nil
  defp preload_pole_validation(v), do: Repo.preload(v, [:pole, :comments])
  defp preload_puzzlet_validation(nil), do: nil
  defp preload_puzzlet_validation(v), do: Repo.preload(v, [:puzzlet, :comments])

  # ──────── Validator status transitions ─────────────────────────────

  def transition_pole_validation_as_validator(%PoleValidation{} = v, validator_id, new_status) do
    do_validator_transition(v, validator_id, new_status, &PoleValidation.changeset/2)
  end

  def transition_puzzlet_validation_as_validator(%PuzzletValidation{} = v, validator_id, new_status) do
    do_validator_transition(v, validator_id, new_status, &PuzzletValidation.changeset/2)
  end

  defp do_validator_transition(validation, validator_id, new_status, changeset_fun) do
    cond do
      validation.validator_id != validator_id ->
        {:error, :not_assignee}

      true ->
        changeset =
          validation
          |> changeset_fun.(%{status: new_status})
          |> Lifecycle.validate_status_transition(validation.status, :validator)

        Repo.update(changeset)
    end
  end

  def update_pole_validation_notes(%PoleValidation{} = v, validator_id, attrs) do
    do_update_notes(v, validator_id, attrs, &PoleValidation.changeset/2)
  end

  def update_puzzlet_validation_notes(%PuzzletValidation{} = v, validator_id, attrs) do
    do_update_notes(v, validator_id, attrs, &PuzzletValidation.changeset/2)
  end

  defp do_update_notes(validation, validator_id, attrs, changeset_fun) do
    cond do
      validation.validator_id != validator_id ->
        {:error, :not_assignee}

      validation.status not in ["assigned", "in_progress"] ->
        {:error, :not_editable}

      true ->
        validation
        |> changeset_fun.(Map.take(attrs, ["overall_notes"]))
        |> Repo.update()
    end
  end

  # ──────── Comment CRUD (validator only, pre-submission) ────────────

  def add_pole_comment(%PoleValidation{} = v, validator_id, attrs) do
    do_add_comment(v, validator_id, attrs, PoleValidationComment, :pole_validation_id)
  end

  def add_puzzlet_comment(%PuzzletValidation{} = v, validator_id, attrs) do
    do_add_comment(v, validator_id, attrs, PuzzletValidationComment, :puzzlet_validation_id)
  end

  defp do_add_comment(validation, validator_id, attrs, schema, fk) do
    cond do
      validation.validator_id != validator_id ->
        {:error, :not_assignee}

      validation.status != "in_progress" ->
        {:error, :not_in_progress}

      true ->
        attrs = Map.put(attrs, fk |> Atom.to_string(), validation.id)

        struct(schema)
        |> schema.changeset(attrs)
        |> Repo.insert()
    end
  end

  def update_pole_comment(%PoleValidationComment{} = c, validator_id, attrs) do
    do_update_comment(c, validator_id, attrs, PoleValidationComment, &get_pole_validation/1)
  end

  def update_puzzlet_comment(%PuzzletValidationComment{} = c, validator_id, attrs) do
    do_update_comment(c, validator_id, attrs, PuzzletValidationComment, &get_puzzlet_validation/1)
  end

  defp do_update_comment(comment, validator_id, attrs, schema, get_fun) do
    parent_id = parent_id_for_comment(comment)
    parent = get_fun.(parent_id)

    cond do
      is_nil(parent) ->
        {:error, :not_found}

      parent.validator_id != validator_id ->
        {:error, :not_assignee}

      parent.status != "in_progress" ->
        {:error, :not_in_progress}

      true ->
        comment
        |> schema.changeset(Map.take(attrs, ["field", "comment", "suggested_value"]))
        |> Repo.update()
    end
  end

  def delete_pole_comment(%PoleValidationComment{} = c, validator_id) do
    do_delete_comment(c, validator_id, &get_pole_validation/1)
  end

  def delete_puzzlet_comment(%PuzzletValidationComment{} = c, validator_id) do
    do_delete_comment(c, validator_id, &get_puzzlet_validation/1)
  end

  defp do_delete_comment(comment, validator_id, get_fun) do
    parent_id = parent_id_for_comment(comment)
    parent = get_fun.(parent_id)

    cond do
      is_nil(parent) ->
        {:error, :not_found}

      parent.validator_id != validator_id ->
        {:error, :not_assignee}

      parent.status != "in_progress" ->
        {:error, :not_in_progress}

      true ->
        Repo.delete(comment)
    end
  end

  def get_pole_comment(id), do: Repo.get(PoleValidationComment, id)
  def get_puzzlet_comment(id), do: Repo.get(PuzzletValidationComment, id)

  defp parent_id_for_comment(%PoleValidationComment{pole_validation_id: id}), do: id
  defp parent_id_for_comment(%PuzzletValidationComment{puzzlet_validation_id: id}), do: id
end
