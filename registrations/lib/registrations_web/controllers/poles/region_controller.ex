defmodule RegistrationsWeb.Poles.RegionController do
  use RegistrationsWeb, :controller

  alias Registrations.Poles.Region
  alias Registrations.Poles.Regions

  def index(conn, params) do
    regions =
      case Map.get(params, "q") do
        nil -> Regions.list_regions()
        q -> Regions.search_regions(q)
      end

    json(conn, %{regions: Enum.map(regions, &render_region/1)})
  end

  def show(conn, %{"id" => id}) do
    case Regions.get_region(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})

      region ->
        json(conn, render_region(region, with_ancestors: true))
    end
  end

  def create(conn, params) do
    user = Pow.Plug.current_user(conn)

    attrs =
      params
      |> Map.take([
        "name",
        "accessibility_tags",
        "accessibility_notes",
        "entry_instructions",
        "parent_region_id"
      ])
      |> Map.put("creator_id", user.id)

    case Regions.create_region(attrs) do
      {:ok, region} ->
        conn |> put_status(:created) |> json(render_region(region, with_ancestors: true))

      {:error, changeset} ->
        render_changeset_error(conn, changeset)
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Regions.get_region(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})

      region ->
        attrs =
          Map.take(params, [
            "name",
            "accessibility_tags",
            "accessibility_notes",
            "entry_instructions",
            "parent_region_id"
          ])

        case Regions.update_region(region, attrs) do
          {:ok, updated} -> json(conn, render_region(updated, with_ancestors: true))
          {:error, changeset} -> render_changeset_error(conn, changeset)
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Regions.get_region(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})

      region ->
        case Regions.delete_region(region) do
          {:ok, _} ->
            send_resp(conn, :no_content, "")

          {:error, :in_use} ->
            conn
            |> put_status(:conflict)
            |> json(%{
              error: %{
                code: "in_use",
                detail: "Region is referenced by puzzlets or sub-regions; clear those first."
              }
            })

          {:error, changeset} ->
            render_changeset_error(conn, changeset)
        end
    end
  end

  defp render_region(%Region{} = region, opts \\ []) do
    base = %{
      id: region.id,
      name: region.name,
      parent_region_id: region.parent_region_id,
      accessibility_tags: region.accessibility_tags || [],
      accessibility_notes: region.accessibility_notes,
      entry_instructions: region.entry_instructions,
      creator_id: region.creator_id,
      inserted_at: region.inserted_at,
      updated_at: region.updated_at
    }

    if Keyword.get(opts, :with_ancestors, false) do
      ancestors =
        region
        |> Regions.ancestor_chain()
        # drop self; chain is root → self, so :init drops the last
        |> Enum.drop(-1)
        |> Enum.map(fn r -> %{id: r.id, name: r.name} end)

      Map.put(base, :ancestors, ancestors)
    else
      base
    end
  end

  defp render_changeset_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(RegistrationsWeb.ChangesetView)
    |> render("error.json", %{changeset: changeset})
  end
end
