defmodule RegistrationsWeb.Poles.BathroomController do
  use RegistrationsWeb, :controller

  alias Registrations.Accounts
  alias Registrations.Poles.Bathroom
  alias Registrations.Poles.Bathrooms

  def index(conn, _params) do
    bathrooms = Bathrooms.list_bathrooms()
    json(conn, %{bathrooms: Enum.map(bathrooms, &render_bathroom/1)})
  end

  def mine(conn, _params) do
    user = Pow.Plug.current_user(conn)
    bathrooms = Bathrooms.list_bathrooms_for(user)
    json(conn, %{bathrooms: Enum.map(bathrooms, &render_bathroom/1)})
  end

  def create(conn, params) do
    user = Pow.Plug.current_user(conn)

    attrs =
      params
      |> Map.take([
        "name",
        "latitude",
        "longitude",
        "accuracy_m",
        "notes",
        "accessibility_tags",
        "accessibility_notes",
        "entry_instructions",
        "region_id"
      ])
      |> Map.put("creator_id", user.id)

    case Bathrooms.create_bathroom(attrs) do
      {:ok, bathroom} ->
        conn |> put_status(:created) |> json(render_bathroom(bathroom))

      {:error, changeset} ->
        render_changeset_error(conn, changeset)
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)

    case Bathrooms.get_bathroom(id) do
      nil ->
        not_found(conn)

      bathroom ->
        if can_modify?(user, bathroom) do
          attrs =
            Map.take(params, [
              "name",
              "latitude",
              "longitude",
              "accuracy_m",
              "notes",
              "accessibility_tags",
              "accessibility_notes",
              "entry_instructions",
              "region_id"
            ])

          case Bathrooms.update_bathroom(bathroom, attrs) do
            {:ok, updated} -> json(conn, render_bathroom(updated))
            {:error, changeset} -> render_changeset_error(conn, changeset)
          end
        else
          forbidden(conn, "You can only edit bathrooms you created.")
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Pow.Plug.current_user(conn)

    case Bathrooms.get_bathroom(id) do
      nil ->
        not_found(conn)

      bathroom ->
        if can_modify?(user, bathroom) do
          {:ok, _} = Bathrooms.delete_bathroom(bathroom)
          send_resp(conn, :no_content, "")
        else
          forbidden(conn, "You can only delete bathrooms you created.")
        end
    end
  end

  # Creator may always modify; supervisors get a global override so they
  # can fix stale or mis-placed entries without bouncing them back to the
  # author.
  defp can_modify?(user, %Bathroom{creator_id: creator_id}) do
    user.id == creator_id or Accounts.has_role?(user, "validation_supervisor")
  end

  defp render_bathroom(%Bathroom{} = b) do
    Map.merge(
      %{
        id: b.id,
        name: b.name,
        latitude: b.latitude,
        longitude: b.longitude,
        accuracy_m: b.accuracy_m,
        notes: b.notes,
        accessibility_tags: b.accessibility_tags || [],
        accessibility_notes: b.accessibility_notes,
        entry_instructions: b.entry_instructions,
        creator_id: b.creator_id,
        inserted_at: b.inserted_at,
        updated_at: b.updated_at
      },
      Bathrooms.inheritance_payload(b)
    )
  end

  defp render_changeset_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(RegistrationsWeb.ChangesetView)
    |> render("error.json", %{changeset: changeset})
  end

  defp not_found(conn) do
    conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})
  end

  defp forbidden(conn, detail) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: %{code: "forbidden", detail: detail}})
  end
end
