defmodule RegistrationsWeb.Landgrab.ValidationController do
  use RegistrationsWeb, :controller

  import Ecto.Query

  alias Ecto.Association.NotLoaded
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.Validations
  alias Registrations.Landgrab.Validations.PoleValidation
  alias Registrations.Landgrab.Validations.PoleValidationComment
  alias Registrations.Landgrab.Validations.PuzzletValidation
  alias Registrations.Landgrab.Validations.PuzzletValidationComment
  alias Registrations.Repo

  def mine(conn, _params) do
    user = Pow.Plug.current_user(conn)
    %{pole_validations: pv, puzzlet_validations: zv} = Validations.list_assignments_for(user.id)

    json(conn, %{
      pole_validations: Enum.map(pv, &render_pole_validation/1),
      puzzlet_validations: Enum.map(zv, &render_puzzlet_validation/1)
    })
  end

  # Validator-facing map endpoint: returns every located puzzlet
  # marked `validator_only` regardless of status, so validators can
  # see the set-aside content on their gameplay map. Answers are
  # deliberately omitted — even a validator looking at their own
  # gameplay map isn't a place to spoil themselves.
  def list_validator_only_puzzlets(conn, _params) do
    puzzlets =
      Puzzlet
      |> where([p], p.validator_only == true)
      |> where([p], not is_nil(p.latitude) and not is_nil(p.longitude))
      |> Repo.all()

    json(conn, %{
      puzzlets:
        Enum.map(puzzlets, fn p ->
          %{
            id: p.id,
            instructions: p.instructions,
            difficulty: p.difficulty,
            latitude: p.latitude,
            longitude: p.longitude,
            warning: p.warning,
            status: p.status
          }
        end)
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

  # Single-action submit of the validator's pole form: the diff (as
  # suggestions), the overall note, and whether they scan-verified it.
  def submit_pole_validation(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)

    case Validations.get_pole_validation(id) do
      nil ->
        not_found(conn)

      validation ->
        attrs = Map.take(params, ["suggestions", "overall_notes", "physically_verified"])

        case Validations.submit_pole_validation(validation, user.id, attrs) do
          {:ok, updated} -> json(conn, render_pole_validation(updated))
          {:error, error} -> handle_error(conn, error)
        end
    end
  end

  def mark_pole_unfindable(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)

    case Validations.get_pole_validation(id) do
      nil ->
        not_found(conn)

      validation ->
        case Validations.mark_pole_unfindable(validation, user.id, params["overall_notes"]) do
          {:ok, updated} -> json(conn, render_pole_validation(updated))
          {:error, error} -> handle_error(conn, error)
        end
    end
  end

  # Identify which pole (if any) a scanned barcode belongs to for this
  # validator, relative to the pole they tapped. See the app's scan
  # routing: matched / other / unknown.
  def resolve_scan(conn, %{"barcode" => barcode} = params) do
    user = Pow.Plug.current_user(conn)
    tapped = params["validation_id"]

    case Validations.resolve_pole_scan(user.id, barcode) do
      {:assigned, vid} ->
        outcome = if vid == tapped, do: "matched", else: "other"
        json(conn, %{outcome: outcome, validation_id: vid, scanned_barcode: barcode})

      :unknown ->
        json(conn, %{outcome: "unknown", validation_id: nil, scanned_barcode: barcode})
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

  defp do_transition(conn, {:ok, validation}, render_fun), do: json(conn, render_fun.(validation))

  defp do_transition(conn, {:error, error}, _), do: handle_error(conn, error)

  defp do_update_notes(conn, {:ok, validation}, render_fun), do: json(conn, render_fun.(validation))

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
      physically_verified: v.physically_verified,
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

  defp render_pole(%NotLoaded{}), do: nil
  defp render_pole(nil), do: nil

  defp render_pole(pole) do
    %{
      id: pole.id,
      barcode: pole.barcode,
      label: pole.label,
      latitude: pole.latitude,
      longitude: pole.longitude,
      accuracy_m: pole.accuracy_m,
      manual_offset_m: pole.manual_offset_m,
      notes: pole.notes,
      status: pole.status,
      attachment_ids: Registrations.Landgrab.list_pole_attachment_ids(pole.id),
      accessibility_tags: pole.accessibility_tags || [],
      accessibility_notes: pole.accessibility_notes
    }
  end

  defp render_puzzlet(%NotLoaded{}), do: nil
  defp render_puzzlet(nil), do: nil

  defp render_puzzlet(puzzlet) do
    Map.merge(
      %{
        id: puzzlet.id,
        instructions: puzzlet.instructions,
        answer: puzzlet.answer,
        answer_type: puzzlet.answer_type,
        difficulty: puzzlet.difficulty,
        status: puzzlet.status,
        latitude: puzzlet.latitude,
        longitude: puzzlet.longitude,
        attachment_ids: Registrations.Landgrab.list_puzzlet_attachment_ids(puzzlet.id),
        accessibility_tags: puzzlet.accessibility_tags || [],
        accessibility_notes: puzzlet.accessibility_notes,
        warning: puzzlet.warning
      },
      Registrations.Landgrab.Regions.puzzlet_inheritance_payload(puzzlet)
    )
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
