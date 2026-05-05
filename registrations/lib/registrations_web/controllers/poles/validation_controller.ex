defmodule RegistrationsWeb.Poles.ValidationController do
  use RegistrationsWeb, :controller

  alias Registrations.Poles.Validations
  alias Registrations.Poles.Validations.PoleValidation
  alias Registrations.Poles.Validations.PoleValidationComment
  alias Registrations.Poles.Validations.PuzzletValidation
  alias Registrations.Poles.Validations.PuzzletValidationComment

  def mine(conn, _params) do
    user = Pow.Plug.current_user(conn)
    %{pole_validations: pv, puzzlet_validations: zv} = Validations.list_assignments_for(user.id)

    json(conn, %{
      pole_validations: Enum.map(pv, &render_pole_validation/1),
      puzzlet_validations: Enum.map(zv, &render_puzzlet_validation/1)
    })
  end

  def update_pole_validation(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)

    case Validations.get_pole_validation(id) do
      nil ->
        not_found(conn)

      validation ->
        cond do
          Map.has_key?(params, "status") ->
            do_transition(
              conn,
              Validations.transition_pole_validation_as_validator(validation, user.id, params["status"]),
              &render_pole_validation/1
            )

          Map.has_key?(params, "overall_notes") ->
            do_update_notes(
              conn,
              Validations.update_pole_validation_notes(validation, user.id, params),
              &render_pole_validation/1
            )

          true ->
            json(conn, render_pole_validation(validation))
        end
    end
  end

  def update_puzzlet_validation(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)

    case Validations.get_puzzlet_validation(id) do
      nil ->
        not_found(conn)

      validation ->
        cond do
          Map.has_key?(params, "status") ->
            do_transition(
              conn,
              Validations.transition_puzzlet_validation_as_validator(validation, user.id, params["status"]),
              &render_puzzlet_validation/1
            )

          Map.has_key?(params, "overall_notes") ->
            do_update_notes(
              conn,
              Validations.update_puzzlet_validation_notes(validation, user.id, params),
              &render_puzzlet_validation/1
            )

          true ->
            json(conn, render_puzzlet_validation(validation))
        end
    end
  end

  def create_pole_comment(conn, %{"validation_id" => vid} = params) do
    user = Pow.Plug.current_user(conn)

    case Validations.get_pole_validation(vid) do
      nil ->
        not_found(conn)

      validation ->
        attrs = Map.take(params, ["field", "comment", "suggested_value"])

        case Validations.add_pole_comment(validation, user.id, attrs) do
          {:ok, comment} ->
            conn |> put_status(:created) |> json(render_comment(comment))

          {:error, error} ->
            handle_error(conn, error)
        end
    end
  end

  def create_puzzlet_comment(conn, %{"validation_id" => vid} = params) do
    user = Pow.Plug.current_user(conn)

    case Validations.get_puzzlet_validation(vid) do
      nil ->
        not_found(conn)

      validation ->
        attrs = Map.take(params, ["field", "comment", "suggested_value"])

        case Validations.add_puzzlet_comment(validation, user.id, attrs) do
          {:ok, comment} ->
            conn |> put_status(:created) |> json(render_comment(comment))

          {:error, error} ->
            handle_error(conn, error)
        end
    end
  end

  def update_pole_comment(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)

    case Validations.get_pole_comment(id) do
      nil ->
        not_found(conn)

      comment ->
        do_update_comment(
          conn,
          Validations.update_pole_comment(comment, user.id, params)
        )
    end
  end

  def update_puzzlet_comment(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)

    case Validations.get_puzzlet_comment(id) do
      nil ->
        not_found(conn)

      comment ->
        do_update_comment(
          conn,
          Validations.update_puzzlet_comment(comment, user.id, params)
        )
    end
  end

  def delete_pole_comment(conn, %{"id" => id}) do
    user = Pow.Plug.current_user(conn)

    case Validations.get_pole_comment(id) do
      nil ->
        not_found(conn)

      comment ->
        case Validations.delete_pole_comment(comment, user.id) do
          {:ok, _} -> send_resp(conn, :no_content, "")
          {:error, error} -> handle_error(conn, error)
        end
    end
  end

  def delete_puzzlet_comment(conn, %{"id" => id}) do
    user = Pow.Plug.current_user(conn)

    case Validations.get_puzzlet_comment(id) do
      nil ->
        not_found(conn)

      comment ->
        case Validations.delete_puzzlet_comment(comment, user.id) do
          {:ok, _} -> send_resp(conn, :no_content, "")
          {:error, error} -> handle_error(conn, error)
        end
    end
  end

  # ──────── Helpers ─────────────────────────────────────────────────

  defp do_transition(conn, {:ok, validation}, render_fun),
    do: json(conn, render_fun.(validation))

  defp do_transition(conn, {:error, error}, _), do: handle_error(conn, error)

  defp do_update_notes(conn, {:ok, validation}, render_fun),
    do: json(conn, render_fun.(validation))

  defp do_update_notes(conn, {:error, error}, _), do: handle_error(conn, error)

  defp do_update_comment(conn, {:ok, comment}), do: json(conn, render_comment(comment))
  defp do_update_comment(conn, {:error, error}), do: handle_error(conn, error)

  defp handle_error(conn, %Ecto.Changeset{} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(RegistrationsWeb.ChangesetView)
    |> render("error.json", %{changeset: changeset})
  end

  defp handle_error(conn, :not_assignee) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: %{code: "not_assignee", detail: "You are not the assigned validator."}})
  end

  defp handle_error(conn, :not_in_progress) do
    conn
    |> put_status(:conflict)
    |> json(%{
      error: %{
        code: "not_in_progress",
        detail: "Comments can only be edited while the validation is in progress."
      }
    })
  end

  defp handle_error(conn, :not_editable) do
    conn
    |> put_status(:conflict)
    |> json(%{error: %{code: "not_editable", detail: "Validation is not editable in this state."}})
  end

  defp handle_error(conn, :not_found) do
    not_found(conn)
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{error: %{code: "not_found"}})
  end

  defp render_pole_validation(%PoleValidation{} = v) do
    %{
      id: v.id,
      status: v.status,
      overall_notes: v.overall_notes,
      pole_id: v.pole_id,
      validator_id: v.validator_id,
      assigned_by_id: v.assigned_by_id,
      pole: render_pole(v.pole),
      comments: Enum.map(v.comments || [], &render_comment/1),
      inserted_at: v.inserted_at,
      updated_at: v.updated_at
    }
  end

  defp render_puzzlet_validation(%PuzzletValidation{} = v) do
    %{
      id: v.id,
      status: v.status,
      overall_notes: v.overall_notes,
      puzzlet_id: v.puzzlet_id,
      validator_id: v.validator_id,
      assigned_by_id: v.assigned_by_id,
      puzzlet: render_puzzlet(v.puzzlet),
      comments: Enum.map(v.comments || [], &render_comment/1),
      inserted_at: v.inserted_at,
      updated_at: v.updated_at
    }
  end

  defp render_pole(%Ecto.Association.NotLoaded{}), do: nil
  defp render_pole(nil), do: nil

  defp render_pole(pole) do
    %{
      id: pole.id,
      barcode: pole.barcode,
      label: pole.label,
      latitude: pole.latitude,
      longitude: pole.longitude,
      notes: pole.notes,
      status: pole.status
    }
  end

  defp render_puzzlet(%Ecto.Association.NotLoaded{}), do: nil
  defp render_puzzlet(nil), do: nil

  defp render_puzzlet(puzzlet) do
    %{
      id: puzzlet.id,
      instructions: puzzlet.instructions,
      answer: puzzlet.answer,
      difficulty: puzzlet.difficulty,
      status: puzzlet.status,
      latitude: puzzlet.latitude,
      longitude: puzzlet.longitude
    }
  end

  defp render_comment(%PoleValidationComment{} = c) do
    %{
      id: c.id,
      field: c.field,
      comment: c.comment,
      suggested_value: c.suggested_value,
      status: c.status
    }
  end

  defp render_comment(%PuzzletValidationComment{} = c) do
    %{
      id: c.id,
      field: c.field,
      comment: c.comment,
      suggested_value: c.suggested_value,
      status: c.status
    }
  end
end
