defmodule RegistrationsWeb.Poles.SupervisionController do
  use RegistrationsWeb, :controller

  alias Registrations.Poles
  alias Registrations.Poles.Pole
  alias Registrations.Poles.Puzzlet
  alias Registrations.Poles.Validations
  alias Registrations.Poles.Validations.PoleValidation
  alias Registrations.Poles.Validations.PoleValidationComment
  alias Registrations.Poles.Validations.PuzzletValidation
  alias Registrations.Poles.Validations.PuzzletValidationComment

  def dashboard(conn, _params) do
    json(conn, Validations.dashboard_counts())
  end

  def list_validators(conn, params) do
    opts =
      case params["exclude_user_id"] do
        nil -> []
        id -> [exclude_user_id: id]
      end

    users = Validations.list_validators(opts)

    json(conn, %{
      validators:
        Enum.map(users, fn u ->
          %{id: u.id, email: u.email, name: u.name}
        end)
    })
  end

  def list_poles(conn, params) do
    poles = Validations.list_poles_for_supervision(%{status: params["status"]})
    json(conn, %{poles: Enum.map(poles, &render_pole/1)})
  end

  def list_puzzlets(conn, params) do
    puzzlets = Validations.list_puzzlets_for_supervision(%{status: params["status"]})
    json(conn, %{puzzlets: Enum.map(puzzlets, &render_puzzlet/1)})
  end

  # ──────── Assign ─────────────────────────────────────────────────

  def assign_pole(conn, %{"id" => pole_id, "validator_id" => validator_id}) do
    user = Pow.Plug.current_user(conn)

    case Validations.assign_pole_validation(pole_id, validator_id, user.id) do
      {:ok, validation} ->
        conn |> put_status(:created) |> json(render_pole_validation(validation))

      {:error, %Ecto.Changeset{} = changeset} ->
        unprocessable(conn, changeset)
    end
  end

  def assign_puzzlet(conn, %{"id" => puzzlet_id, "validator_id" => validator_id}) do
    user = Pow.Plug.current_user(conn)

    case Validations.assign_puzzlet_validation(puzzlet_id, validator_id, user.id) do
      {:ok, validation} ->
        conn |> put_status(:created) |> json(render_puzzlet_validation(validation))

      {:error, %Ecto.Changeset{} = changeset} ->
        unprocessable(conn, changeset)
    end
  end

  # ──────── Accept / reject validation ─────────────────────────────

  def update_pole_validation(conn, %{"id" => id, "status" => status}) do
    case Validations.get_pole_validation(id) do
      nil ->
        not_found(conn)

      validation ->
        result =
          case status do
            "accepted" -> Validations.accept_pole_validation(validation)
            "rejected" -> Validations.reject_pole_validation(validation)
            _ -> {:error, :bad_status}
          end

        case result do
          {:ok, updated} -> json(conn, render_pole_validation(updated))
          {:error, :bad_status} -> unprocessable(conn, "status must be 'accepted' or 'rejected'")
          {:error, %Ecto.Changeset{} = c} -> unprocessable(conn, c)
        end
    end
  end

  def update_puzzlet_validation(conn, %{"id" => id, "status" => status}) do
    case Validations.get_puzzlet_validation(id) do
      nil ->
        not_found(conn)

      validation ->
        result =
          case status do
            "accepted" -> Validations.accept_puzzlet_validation(validation)
            "rejected" -> Validations.reject_puzzlet_validation(validation)
            _ -> {:error, :bad_status}
          end

        case result do
          {:ok, updated} -> json(conn, render_puzzlet_validation(updated))
          {:error, :bad_status} -> unprocessable(conn, "status must be 'accepted' or 'rejected'")
          {:error, %Ecto.Changeset{} = c} -> unprocessable(conn, c)
        end
    end
  end

  # ──────── Decide a single comment (apply suggestion) ─────────────

  def update_pole_comment(conn, %{"id" => id, "status" => status}) do
    case Validations.get_pole_comment(id) do
      nil ->
        not_found(conn)

      comment ->
        result =
          case status do
            "accepted" -> Validations.accept_pole_comment(comment)
            "rejected" -> Validations.reject_pole_comment(comment)
            _ -> {:error, :bad_status}
          end

        case result do
          {:ok, updated} -> json(conn, render_comment(updated))
          {:error, :bad_status} -> unprocessable(conn, "status must be 'accepted' or 'rejected'")
          {:error, :bad_number} ->
            unprocessable(conn, "suggested_value cannot be parsed as a number")

          {:error, %Ecto.Changeset{} = c} -> unprocessable(conn, c)
        end
    end
  end

  def update_puzzlet_comment(conn, %{"id" => id, "status" => status}) do
    case Validations.get_puzzlet_comment(id) do
      nil ->
        not_found(conn)

      comment ->
        result =
          case status do
            "accepted" -> Validations.accept_puzzlet_comment(comment)
            "rejected" -> Validations.reject_puzzlet_comment(comment)
            _ -> {:error, :bad_status}
          end

        case result do
          {:ok, updated} -> json(conn, render_comment(updated))
          {:error, :bad_status} -> unprocessable(conn, "status must be 'accepted' or 'rejected'")
          {:error, :bad_number} ->
            unprocessable(conn, "suggested_value cannot be parsed as a number")

          {:error, %Ecto.Changeset{} = c} -> unprocessable(conn, c)
        end
    end
  end

  # ──────── Direct edits to target ─────────────────────────────────

  def update_pole(conn, %{"id" => id} = params) do
    case Poles.get_pole!(id) do
      nil ->
        not_found(conn)

      pole ->
        attrs =
          Map.take(params, ["barcode", "label", "latitude", "longitude", "notes", "accuracy_m", "status"])

        case Validations.supervisor_update_pole(pole, attrs) do
          {:ok, updated} -> json(conn, render_pole(updated))
          {:error, c} -> unprocessable(conn, c)
        end
    end
  rescue
    Ecto.NoResultsError -> not_found(conn)
  end

  def update_puzzlet(conn, %{"id" => id} = params) do
    case Poles.get_puzzlet(id) do
      nil ->
        not_found(conn)

      puzzlet ->
        attrs =
          Map.take(params, [
            "instructions",
            "answer",
            "difficulty",
            "latitude",
            "longitude",
            "accuracy_m",
            "pole_id",
            "status"
          ])

        case Validations.supervisor_update_puzzlet(puzzlet, attrs) do
          {:ok, updated} -> json(conn, render_puzzlet(updated))
          {:error, c} -> unprocessable(conn, c)
        end
    end
  end

  # ──────── Helpers / renderers ────────────────────────────────────

  defp unprocessable(conn, %Ecto.Changeset{} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(RegistrationsWeb.ChangesetView)
    |> render("error.json", %{changeset: changeset})
  end

  defp unprocessable(conn, message) when is_binary(message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{detail: message}})
  end

  defp not_found(conn) do
    conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})
  end

  defp render_pole(%Pole{} = pole) do
    %{
      id: pole.id,
      barcode: pole.barcode,
      label: pole.label,
      latitude: pole.latitude,
      longitude: pole.longitude,
      notes: pole.notes,
      accuracy_m: pole.accuracy_m,
      status: pole.status,
      creator_id: pole.creator_id
    }
  end

  defp render_puzzlet(%Puzzlet{} = puzzlet) do
    %{
      id: puzzlet.id,
      instructions: puzzlet.instructions,
      answer: puzzlet.answer,
      difficulty: puzzlet.difficulty,
      status: puzzlet.status,
      pole_id: puzzlet.pole_id,
      latitude: puzzlet.latitude,
      longitude: puzzlet.longitude,
      creator_id: puzzlet.creator_id
    }
  end

  defp render_pole_validation(%PoleValidation{} = v) do
    %{
      id: v.id,
      status: v.status,
      pole_id: v.pole_id,
      validator_id: v.validator_id,
      assigned_by_id: v.assigned_by_id,
      overall_notes: v.overall_notes,
      pole: render_assoc(v.pole, &render_pole/1),
      comments: render_comments(v.comments)
    }
  end

  defp render_puzzlet_validation(%PuzzletValidation{} = v) do
    %{
      id: v.id,
      status: v.status,
      puzzlet_id: v.puzzlet_id,
      validator_id: v.validator_id,
      assigned_by_id: v.assigned_by_id,
      overall_notes: v.overall_notes,
      puzzlet: render_assoc(v.puzzlet, &render_puzzlet/1),
      comments: render_comments(v.comments)
    }
  end

  defp render_assoc(%Ecto.Association.NotLoaded{}, _), do: nil
  defp render_assoc(nil, _), do: nil
  defp render_assoc(record, fun), do: fun.(record)

  defp render_comments(%Ecto.Association.NotLoaded{}), do: []
  defp render_comments(nil), do: []
  defp render_comments(list), do: Enum.map(list, &render_comment/1)

  defp render_comment(%PoleValidationComment{} = c), do: render_comment_map(c)
  defp render_comment(%PuzzletValidationComment{} = c), do: render_comment_map(c)

  defp render_comment_map(c) do
    %{
      id: c.id,
      field: c.field,
      comment: c.comment,
      suggested_value: c.suggested_value,
      status: c.status
    }
  end
end
