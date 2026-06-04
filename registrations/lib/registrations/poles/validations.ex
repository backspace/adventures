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
        preload_validator(validation)
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
        preload_validator(validation)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  # User lives in the `public` schema. Without an explicit prefix the
  # association inherits the parent's `poles` prefix and Ecto tries to
  # read from `poles.users` (which doesn't exist).
  defp preload_validator(validation) do
    user_query = from(u in RegistrationsWeb.User, prefix: "public")
    Repo.preload(validation, [validator: user_query], force: true)
  end

  defp maybe_flip_pole(%Pole{status: :draft} = pole, new_status) do
    pole |> Ecto.Changeset.change(status: new_status) |> Repo.update()
  end

  defp maybe_flip_pole(pole, _), do: {:ok, pole}

  defp maybe_flip_puzzlet(%Puzzlet{status: :draft} = puzzlet, new_status) do
    puzzlet |> Ecto.Changeset.change(status: new_status) |> Repo.update()
  end

  defp maybe_flip_puzzlet(puzzlet, _), do: {:ok, puzzlet}

  @doc """
  Swap the validator on an existing validation in place. Permitted only
  while the validation is still in flight (`assigned` or `in_progress`);
  once submitted/accepted/rejected the validation is the validator's
  artifact and must be resolved through the lifecycle instead.

  Comments stay attached — they're about the entity, not the validator.
  """
  def reassign_pole_validation(%PoleValidation{} = v, new_validator_id, assigner_id) do
    do_reassign(v, new_validator_id, assigner_id, &PoleValidation.changeset/2)
  end

  def reassign_puzzlet_validation(%PuzzletValidation{} = v, new_validator_id, assigner_id) do
    do_reassign(v, new_validator_id, assigner_id, &PuzzletValidation.changeset/2)
  end

  defp do_reassign(validation, new_validator_id, assigner_id, changeset_fun) do
    if validation.status in ["assigned", "in_progress"] do
      result =
        validation
        |> changeset_fun.(%{
          validator_id: new_validator_id,
          assigned_by_id: assigner_id
        })
        |> Repo.update()

      case result do
        {:ok, updated} -> {:ok, preload_validator(updated)}
        err -> err
      end
    else
      {:error, :terminal_status}
    end
  end

  @doc """
  Tear down a fresh assignment (for the supervisor's "undo" affordance).
  Allowed only while the validation has just been assigned and has no
  comments yet — anything beyond that represents validator work we don't
  want to silently discard. If unassigning leaves the parent pole/puzzlet
  with no validations at all, its status flips back to :draft so the
  author can pick it up again.
  """
  def unassign_pole_validation(%PoleValidation{} = v) do
    if unassignable?(v) do
      Repo.transaction(fn ->
        {:ok, _} = Repo.delete(v)
        maybe_revert_pole_status(v.pole_id)
        :ok
      end)
    else
      {:error, :not_unassignable}
    end
  end

  def unassign_puzzlet_validation(%PuzzletValidation{} = v) do
    if unassignable?(v) do
      Repo.transaction(fn ->
        {:ok, _} = Repo.delete(v)
        maybe_revert_puzzlet_status(v.puzzlet_id)
        :ok
      end)
    else
      {:error, :not_unassignable}
    end
  end

  defp unassignable?(%{status: "assigned"} = v) do
    case v do
      %PoleValidation{} ->
        not Repo.exists?(
          from(c in Registrations.Poles.Validations.PoleValidationComment,
            where: c.pole_validation_id == ^v.id
          )
        )

      %PuzzletValidation{} ->
        not Repo.exists?(
          from(c in Registrations.Poles.Validations.PuzzletValidationComment,
            where: c.puzzlet_validation_id == ^v.id
          )
        )
    end
  end

  defp unassignable?(_), do: false

  defp maybe_revert_pole_status(pole_id) do
    others_exist? =
      Repo.exists?(from(v in PoleValidation, where: v.pole_id == ^pole_id))

    pole = Repo.get!(Pole, pole_id)

    if not others_exist? and pole.status == :in_review do
      pole |> Ecto.Changeset.change(status: :draft) |> Repo.update!()
    end
  end

  defp maybe_revert_puzzlet_status(puzzlet_id) do
    others_exist? =
      Repo.exists?(from(v in PuzzletValidation, where: v.puzzlet_id == ^puzzlet_id))

    puzzlet = Repo.get!(Puzzlet, puzzlet_id)

    if not others_exist? and puzzlet.status == :in_review do
      puzzlet |> Ecto.Changeset.change(status: :draft) |> Repo.update!()
    end
  end

  # ──────── Validator queries ────────────────────────────────────────

  def list_assignments_for(validator_id) do
    pole =
      PoleValidation
      |> where([v], v.validator_id == ^validator_id)
      |> where([v], v.status not in ^["accepted", "rejected"])
      |> order_by([v], desc: v.updated_at)
      |> Repo.all()
      |> Repo.preload([:pole, :comments])

    puzzlet =
      PuzzletValidation
      |> where([v], v.validator_id == ^validator_id)
      |> where([v], v.status not in ^["accepted", "rejected"])
      |> order_by([v], desc: v.updated_at)
      |> Repo.all()
      |> Repo.preload([:puzzlet, :comments])

    %{pole_validations: pole, puzzlet_validations: puzzlet}
  end

  def get_pole_validation(id), do: Repo.get(PoleValidation, id) |> preload_pole_validation()
  def get_puzzlet_validation(id), do: Repo.get(PuzzletValidation, id) |> preload_puzzlet_validation()

  defp preload_pole_validation(nil), do: nil
  defp preload_pole_validation(v) do
    v
    |> Repo.preload([:pole, :comments])
    |> preload_validator()
  end
  defp preload_puzzlet_validation(nil), do: nil
  defp preload_puzzlet_validation(v) do
    v
    |> Repo.preload([:puzzlet, :comments])
    |> preload_validator()
  end

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
        |> tap(fn
          {:ok, _} -> touch_validation_and_parent(validation)
          _ -> :ok
        end)
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
        |> tap(fn
          {:ok, _} -> touch_validation_and_parent(parent)
          _ -> :ok
        end)
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
        |> tap(fn
          {:ok, _} -> touch_validation_and_parent(parent)
          _ -> :ok
        end)
    end
  end

  def get_pole_comment(id), do: Repo.get(PoleValidationComment, id)
  def get_puzzlet_comment(id), do: Repo.get(PuzzletValidationComment, id)

  defp parent_id_for_comment(%PoleValidationComment{pole_validation_id: id}), do: id
  defp parent_id_for_comment(%PuzzletValidationComment{puzzlet_validation_id: id}), do: id

  defp touch_validation_and_parent(%PoleValidation{id: id, pole_id: pole_id}) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    Repo.update_all(from(v in PoleValidation, where: v.id == ^id), set: [updated_at: now])
    Repo.update_all(from(p in Pole, where: p.id == ^pole_id), set: [updated_at: now])
    :ok
  end

  defp touch_validation_and_parent(%PuzzletValidation{id: id, puzzlet_id: puzzlet_id}) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    Repo.update_all(from(v in PuzzletValidation, where: v.id == ^id), set: [updated_at: now])
    Repo.update_all(from(p in Puzzlet, where: p.id == ^puzzlet_id), set: [updated_at: now])
    :ok
  end

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

  @doc """
  For a list of pole ids, returns a map of pole_id => latest active
  (non-terminal) PoleValidation, with comments preloaded. Poles without an
  active validation are absent from the map.
  """
  def active_validations_by_pole(pole_ids) when is_list(pole_ids) do
    PoleValidation
    |> where([v], v.pole_id in ^pole_ids)
    |> where([v], v.status not in ^["accepted", "rejected"])
    |> order_by([v], desc: v.inserted_at)
    |> Repo.all()
    |> Repo.preload(:comments)
    |> Enum.group_by(& &1.pole_id)
    |> Map.new(fn {pole_id, vs} -> {pole_id, hd(vs)} end)
  end

  def active_validations_by_puzzlet(puzzlet_ids) when is_list(puzzlet_ids) do
    PuzzletValidation
    |> where([v], v.puzzlet_id in ^puzzlet_ids)
    |> where([v], v.status not in ^["accepted", "rejected"])
    |> order_by([v], desc: v.inserted_at)
    |> Repo.all()
    |> Repo.preload(:comments)
    |> Enum.group_by(& &1.puzzlet_id)
    |> Map.new(fn {puzzlet_id, vs} -> {puzzlet_id, hd(vs)} end)
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
    |> order_by([p], desc: p.updated_at)
    |> Repo.all()
  end

  def list_puzzlets_for_supervision(filter \\ %{}) do
    Puzzlet
    |> filter_by_status(filter[:status])
    |> order_by([p], desc: p.updated_at)
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
    pole_validation_counts = count_by_validation_status(PoleValidation)
    puzzlet_validation_counts = count_by_validation_status(PuzzletValidation)

    %{
      poles: pole_counts,
      puzzlets: puzzlet_counts,
      pole_validations: pole_validation_counts,
      puzzlet_validations: puzzlet_validation_counts
    }
  end

  defp count_by_status(schema) do
    from(s in schema, group_by: s.status, select: {s.status, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  defp count_by_validation_status(schema) do
    from(v in schema, group_by: v.status, select: {v.status, count(v.id)})
    |> Repo.all()
    |> Map.new()
  end
end
