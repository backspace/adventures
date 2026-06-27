defmodule RegistrationsWeb.Landgrab.DraftController do
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Pole
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.Regions

  def index(conn, _params) do
    user = Pow.Plug.current_user(conn)
    %{poles: poles, puzzlets: puzzlets} = Landgrab.list_drafts_for_user(user)

    json(conn, %{
      poles: Enum.map(poles, &render_pole/1),
      puzzlets: Enum.map(puzzlets, &render_puzzlet/1)
    })
  end

  def create_pole(conn, params) do
    user = Pow.Plug.current_user(conn)

    attrs =
      params
      |> Map.take([
        "barcode",
        "label",
        "latitude",
        "longitude",
        "notes",
        "accuracy_m",
        "accessibility_tags",
        "accessibility_notes"
      ])
      |> Map.put("creator_id", user.id)
      |> Map.put("status", "draft")

    case Landgrab.create_pole(attrs) do
      {:ok, pole} ->
        conn |> put_status(:created) |> json(render_pole(pole))

      {:error, changeset} ->
        render_changeset_error(conn, changeset)
    end
  end

  def update_pole(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)
    pole = Landgrab.get_pole!(id)

    cond do
      pole.creator_id != user.id ->
        forbidden(conn, "You can only edit drafts you created.")

      pole.status != :draft ->
        forbidden(conn, "Only drafts can be edited; this pole is #{pole.status}.")

      true ->
        attrs =
          Map.take(params, [
            "label",
            "latitude",
            "longitude",
            "notes",
            "accuracy_m",
            "barcode",
            "accessibility_tags",
            "accessibility_notes"
          ])

        case Landgrab.update_pole(pole, attrs) do
          {:ok, updated} -> json(conn, render_pole(updated))
          {:error, changeset} -> render_changeset_error(conn, changeset)
        end
    end
  end

  def delete_pole(conn, %{"id" => id}) do
    user = Pow.Plug.current_user(conn)
    pole = Landgrab.get_pole!(id)

    cond do
      pole.creator_id != user.id ->
        forbidden(conn, "You can only delete drafts you created.")

      pole.status != :draft ->
        forbidden(conn, "Only drafts can be deleted; this pole is #{pole.status}.")

      true ->
        {:ok, _} = Landgrab.delete_pole(pole)
        send_resp(conn, :no_content, "")
    end
  end

  def create_puzzlet(conn, params) do
    user = Pow.Plug.current_user(conn)

    attrs =
      params
      |> Map.take([
        "instructions",
        "answer",
        "answer_type",
        "difficulty",
        "latitude",
        "longitude",
        "accuracy_m",
        "accessibility_tags",
        "accessibility_notes",
        "region_id",
        "warning"
      ])
      |> Map.put("creator_id", user.id)
      |> Map.put("status", "draft")

    case Landgrab.create_puzzlet(attrs) do
      {:ok, puzzlet} ->
        conn |> put_status(:created) |> json(render_puzzlet(puzzlet))

      {:error, changeset} ->
        render_changeset_error(conn, changeset)
    end
  end

  def update_puzzlet(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)
    puzzlet = Landgrab.get_puzzlet(id)

    cond do
      is_nil(puzzlet) ->
        conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})

      puzzlet.creator_id != user.id ->
        forbidden(conn, "You can only edit drafts you created.")

      puzzlet.status != :draft ->
        forbidden(conn, "Only drafts can be edited; this puzzlet is #{puzzlet.status}.")

      true ->
        attrs =
          Map.take(params, [
            "instructions",
            "answer",
            "answer_type",
            "difficulty",
            "latitude",
            "longitude",
            "accuracy_m",
            "accessibility_tags",
            "accessibility_notes",
            "region_id",
            "warning"
          ])

        case Landgrab.update_puzzlet(puzzlet, attrs) do
          {:ok, updated} -> json(conn, render_puzzlet(updated))
          {:error, changeset} -> render_changeset_error(conn, changeset)
        end
    end
  end

  def delete_puzzlet(conn, %{"id" => id}) do
    user = Pow.Plug.current_user(conn)
    puzzlet = Landgrab.get_puzzlet(id)

    cond do
      is_nil(puzzlet) ->
        conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})

      puzzlet.creator_id != user.id ->
        forbidden(conn, "You can only delete drafts you created.")

      puzzlet.status != :draft ->
        forbidden(conn, "Only drafts can be deleted; this puzzlet is #{puzzlet.status}.")

      true ->
        {:ok, _} = Landgrab.delete_puzzlet(puzzlet)
        send_resp(conn, :no_content, "")
    end
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
      creator_id: pole.creator_id,
      inserted_at: pole.inserted_at,
      attachment_ids: Landgrab.list_pole_attachment_ids(pole.id),
      accessibility_tags: pole.accessibility_tags || [],
      accessibility_notes: pole.accessibility_notes
    }
  end

  defp render_puzzlet(%Puzzlet{} = puzzlet) do
    Map.merge(
      %{
        id: puzzlet.id,
        instructions: puzzlet.instructions,
        answer: puzzlet.answer,
        answer_type: puzzlet.answer_type,
        difficulty: puzzlet.difficulty,
        status: puzzlet.status,
        pole_id: puzzlet.pole_id,
        creator_id: puzzlet.creator_id,
        latitude: puzzlet.latitude,
        longitude: puzzlet.longitude,
        accuracy_m: puzzlet.accuracy_m,
        inserted_at: puzzlet.inserted_at,
        attachment_ids: Landgrab.list_puzzlet_attachment_ids(puzzlet.id),
        accessibility_tags: puzzlet.accessibility_tags || [],
        accessibility_notes: puzzlet.accessibility_notes,
        warning: puzzlet.warning
      },
      Regions.puzzlet_inheritance_payload(puzzlet)
    )
  end

  defp render_changeset_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(RegistrationsWeb.ChangesetView)
    |> render("error.json", %{changeset: changeset})
  end

  defp forbidden(conn, detail) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: %{code: "forbidden", detail: detail}})
  end
end
