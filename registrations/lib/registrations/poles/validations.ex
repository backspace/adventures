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

  # ──────── Supervisor: accept/reject validations ────────────────────

  def accept_pole_validation(%PoleValidation{} = v) do
    decide_pole_validation(v, "accepted", :validated)
  end

  def reject_pole_validation(%PoleValidation{} = v) do
    decide_pole_validation(v, "rejected", :draft)
  end

  defp decide_pole_validation(validation, new_status, target_status) do
    Repo.transaction(fn ->
      changeset =
        validation
        |> PoleValidation.changeset(%{status: new_status})
        |> Lifecycle.validate_status_transition(validation.status, :supervisor)

      with {:ok, updated} <- Repo.update(changeset),
           pole <- Repo.get!(Pole, validation.pole_id),
           {:ok, _} <- pole |> Ecto.Changeset.change(status: target_status) |> Repo.update() do
        updated
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def accept_puzzlet_validation(%PuzzletValidation{} = v) do
    decide_puzzlet_validation(v, "accepted", :validated)
  end

  def reject_puzzlet_validation(%PuzzletValidation{} = v) do
    decide_puzzlet_validation(v, "rejected", :draft)
  end

  defp decide_puzzlet_validation(validation, new_status, target_status) do
    Repo.transaction(fn ->
      changeset =
        validation
        |> PuzzletValidation.changeset(%{status: new_status})
        |> Lifecycle.validate_status_transition(validation.status, :supervisor)

      with {:ok, updated} <- Repo.update(changeset),
           puzzlet <- Repo.get!(Puzzlet, validation.puzzlet_id),
           {:ok, _} <- puzzlet |> Ecto.Changeset.change(status: target_status) |> Repo.update() do
        updated
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  # ──────── Supervisor: decide comments (apply suggestion) ───────────

  def accept_pole_comment(%PoleValidationComment{} = comment) do
    apply_comment_decision(comment, "accepted", &apply_pole_suggestion/2)
  end

  def reject_pole_comment(%PoleValidationComment{} = comment) do
    apply_comment_decision(comment, "rejected", fn _, _ -> :ok end)
  end

  def accept_puzzlet_comment(%PuzzletValidationComment{} = comment) do
    apply_comment_decision(comment, "accepted", &apply_puzzlet_suggestion/2)
  end

  def reject_puzzlet_comment(%PuzzletValidationComment{} = comment) do
    apply_comment_decision(comment, "rejected", fn _, _ -> :ok end)
  end

  defp apply_comment_decision(comment, new_status, apply_fun) do
    Repo.transaction(fn ->
      cs =
        case comment do
          %PoleValidationComment{} -> PoleValidationComment.changeset(comment, %{status: new_status})
          %PuzzletValidationComment{} -> PuzzletValidationComment.changeset(comment, %{status: new_status})
        end

      with {:ok, updated} <- Repo.update(cs),
           :ok <- maybe_apply(apply_fun, updated) do
        updated
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  defp maybe_apply(_fun, %{status: status} = _comment) when status != "accepted", do: :ok

  defp maybe_apply(fun, comment) do
    case fun.(comment, comment.suggested_value) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp apply_pole_suggestion(_comment, nil), do: :ok

  defp apply_pole_suggestion(%PoleValidationComment{} = c, suggested) do
    parent = Repo.get!(PoleValidation, c.pole_validation_id)
    pole = Repo.get!(Pole, parent.pole_id)
    apply_field_to(pole, c.field, suggested, &Pole.changeset/2)
  end

  defp apply_puzzlet_suggestion(_comment, nil), do: :ok

  defp apply_puzzlet_suggestion(%PuzzletValidationComment{} = c, suggested) do
    parent = Repo.get!(PuzzletValidation, c.puzzlet_validation_id)
    puzzlet = Repo.get!(Puzzlet, parent.puzzlet_id)
    apply_field_to(puzzlet, c.field, suggested, &Puzzlet.changeset/2)
  end

  defp apply_field_to(record, field, raw_value, changeset_fun) do
    with {:ok, parsed} <- coerce_value(field, raw_value),
         attrs <- %{field => parsed},
         {:ok, _} <- record |> changeset_fun.(attrs) |> Repo.update() do
      :ok
    end
  end

  defp coerce_value("latitude", v), do: parse_float(v)
  defp coerce_value("longitude", v), do: parse_float(v)
  defp coerce_value("difficulty", v), do: parse_int(v)
  defp coerce_value(_, v), do: {:ok, v}

  defp parse_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, ""} -> {:ok, f}
      _ -> {:error, :bad_number}
    end
  end

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {i, ""} -> {:ok, i}
      _ -> {:error, :bad_number}
    end
  end

  # ──────── Supervisor: direct edit of target ────────────────────────

  def supervisor_update_pole(%Pole{} = pole, attrs) do
    pole
    |> Pole.changeset(attrs)
    |> Repo.update()
  end

  def supervisor_update_puzzlet(%Puzzlet{} = puzzlet, attrs) do
    puzzlet
    |> Puzzlet.changeset(attrs)
    |> Repo.update()
  end

  # ──────── Supervisor: lookups for the dashboard / pickers ──────────

  @doc """
  Lists users with the validator role. If `exclude_user_id` is given, that
  user is filtered out — useful when the picker is for a specific pole or
  puzzlet whose creator can't validate it.
  """
  def list_validators(opts \\ []) do
    exclude = Keyword.get(opts, :exclude_user_id)

    query =
      from(r in Registrations.UserRole,
        where: r.role == "validator",
        join: u in RegistrationsWeb.User,
        on: u.id == r.user_id,
        select: u
      )

    query = if exclude, do: where(query, [r, u], u.id != ^exclude), else: query

    Repo.all(query)
  end

  def list_validations_for_pole(pole_id) do
    PoleValidation
    |> where([v], v.pole_id == ^pole_id)
    |> order_by([v], desc: v.inserted_at)
    |> Repo.all()
    |> Repo.preload([:comments])
  end

  def list_validations_for_puzzlet(puzzlet_id) do
    PuzzletValidation
    |> where([v], v.puzzlet_id == ^puzzlet_id)
    |> order_by([v], desc: v.inserted_at)
    |> Repo.all()
    |> Repo.preload([:comments])
  end

  def list_poles_for_supervision(filter \\ %{}) do
    Pole
    |> filter_by_status(filter[:status])
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  def list_puzzlets_for_supervision(filter \\ %{}) do
    Puzzlet
    |> filter_by_status(filter[:status])
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, ""), do: query

  defp filter_by_status(query, status) when is_binary(status) do
    where(query, [p], p.status == ^status)
  end

  def dashboard_counts do
    pole_counts = count_by_status(Pole)
    puzzlet_counts = count_by_status(Puzzlet)
    submitted_pv = count_by_validation_status(PoleValidation, "submitted")
    submitted_zv = count_by_validation_status(PuzzletValidation, "submitted")

    %{
      poles: pole_counts,
      puzzlets: puzzlet_counts,
      pole_validations_submitted: submitted_pv,
      puzzlet_validations_submitted: submitted_zv
    }
  end

  defp count_by_status(schema) do
    from(s in schema, group_by: s.status, select: {s.status, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  defp count_by_validation_status(schema, status) do
    Repo.aggregate(from(v in schema, where: v.status == ^status), :count, :id)
  end
end
