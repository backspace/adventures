defmodule RegistrationsWeb.Poles.DraftController do
  use RegistrationsWeb, :controller

  alias Registrations.Poles
  alias Registrations.Poles.Pole
  alias Registrations.Poles.Puzzlet

  def index(conn, _params) do
    user = Pow.Plug.current_user(conn)
    %{poles: poles, puzzlets: puzzlets} = Poles.list_drafts_for_user(user)

    json(conn, %{
      poles: Enum.map(poles, &render_pole/1),
      puzzlets: Enum.map(puzzlets, &render_puzzlet/1)
    })
  end

  def create_pole(conn, params) do
    user = Pow.Plug.current_user(conn)

    attrs =
      params
      |> Map.take(["barcode", "label", "latitude", "longitude", "notes", "accuracy_m"])
      |> Map.put("creator_id", user.id)
      |> Map.put("status", "draft")

    case Poles.create_pole(attrs) do
      {:ok, pole} ->
        conn |> put_status(:created) |> json(render_pole(pole))

      {:error, changeset} ->
        render_changeset_error(conn, changeset)
    end
  end

  def update_pole(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)
    pole = Poles.get_pole!(id)

    cond do
      pole.creator_id != user.id ->
        forbidden(conn, "You can only edit drafts you created.")

      pole.status != :draft ->
        forbidden(conn, "Only drafts can be edited; this pole is #{pole.status}.")

      true ->
        attrs =
          params
          |> Map.take(["label", "latitude", "longitude", "notes", "accuracy_m", "barcode"])

        case Poles.update_pole(pole, attrs) do
          {:ok, updated} -> json(conn, render_pole(updated))
          {:error, changeset} -> render_changeset_error(conn, changeset)
        end
    end
  end

  def delete_pole(conn, %{"id" => id}) do
    user = Pow.Plug.current_user(conn)
    pole = Poles.get_pole!(id)

    cond do
      pole.creator_id != user.id ->
        forbidden(conn, "You can only delete drafts you created.")

      pole.status != :draft ->
        forbidden(conn, "Only drafts can be deleted; this pole is #{pole.status}.")

      true ->
        {:ok, _} = Poles.delete_pole(pole)
        send_resp(conn, :no_content, "")
    end
  end

  def create_puzzlet(conn, params) do
    user = Pow.Plug.current_user(conn)

    attrs =
      params
      |> Map.take(["instructions", "answer", "difficulty"])
      |> Map.put("creator_id", user.id)
      |> Map.put("status", "draft")

    case Poles.create_puzzlet(attrs) do
      {:ok, puzzlet} ->
        conn |> put_status(:created) |> json(render_puzzlet(puzzlet))

      {:error, changeset} ->
        render_changeset_error(conn, changeset)
    end
  end

  def update_puzzlet(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)
    puzzlet = Poles.get_puzzlet(id)

    cond do
      is_nil(puzzlet) ->
        conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})

      puzzlet.creator_id != user.id ->
        forbidden(conn, "You can only edit drafts you created.")

      puzzlet.status != :draft ->
        forbidden(conn, "Only drafts can be edited; this puzzlet is #{puzzlet.status}.")

      true ->
        attrs = Map.take(params, ["instructions", "answer", "difficulty"])

        case Poles.update_puzzlet(puzzlet, attrs) do
          {:ok, updated} -> json(conn, render_puzzlet(updated))
          {:error, changeset} -> render_changeset_error(conn, changeset)
        end
    end
  end

  def delete_puzzlet(conn, %{"id" => id}) do
    user = Pow.Plug.current_user(conn)
    puzzlet = Poles.get_puzzlet(id)

    cond do
      is_nil(puzzlet) ->
        conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})

      puzzlet.creator_id != user.id ->
        forbidden(conn, "You can only delete drafts you created.")

      puzzlet.status != :draft ->
        forbidden(conn, "Only drafts can be deleted; this puzzlet is #{puzzlet.status}.")

      true ->
        {:ok, _} = Poles.delete_puzzlet(puzzlet)
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
      inserted_at: pole.inserted_at
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
      creator_id: puzzlet.creator_id,
      inserted_at: puzzlet.inserted_at
    }
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
