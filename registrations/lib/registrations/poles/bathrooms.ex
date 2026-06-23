defmodule Registrations.Poles.Bathrooms do
  @moduledoc """
  Context for bathrooms — author-published, no validation lifecycle.
  Mirrors the puzzlet pattern for region inheritance so accessibility
  data attached to a parent region surfaces alongside the bathroom's own.
  """
  import Ecto.Query, warn: false

  alias Registrations.Poles.Bathroom
  alias Registrations.Poles.Regions
  alias Registrations.Repo

  def list_bathrooms do
    Bathroom
    |> order_by([b], asc: b.name, asc: b.inserted_at)
    |> Repo.all()
  end

  def list_bathrooms_for(%{id: user_id}) do
    Bathroom
    |> where([b], b.creator_id == ^user_id)
    |> order_by([b], desc: b.updated_at)
    |> Repo.all()
  end

  def get_bathroom(id), do: Repo.get(Bathroom, id)

  def create_bathroom(attrs) do
    %Bathroom{}
    |> Bathroom.changeset(attrs)
    |> Repo.insert()
  end

  def update_bathroom(%Bathroom{} = bathroom, attrs) do
    bathroom
    |> Bathroom.changeset(attrs)
    |> Repo.update()
  end

  def delete_bathroom(%Bathroom{} = bathroom), do: Repo.delete(bathroom)

  @doc """
  Convenience shape for bathroom JSON renderers — mirrors
  `Regions.puzzlet_inheritance_payload/1` so the Flutter side can use the
  same `region` / `inherited_tags` / `inherited_stanzas` keys.
  """
  def inheritance_payload(%Bathroom{region_id: region_id}) do
    chain = Regions.ancestor_chain(region_id)
    %{inherited_tags: tags, inherited_stanzas: stanzas} = Regions.inherited(chain)

    %{
      region_id: region_id,
      region: region_summary(chain),
      inherited_tags: tags,
      inherited_stanzas: stanzas
    }
  end

  defp region_summary([]), do: nil

  defp region_summary(chain) when is_list(chain) do
    self = List.last(chain)
    breadcrumb = chain |> Enum.map(& &1.name) |> Enum.join(" > ")
    %{id: self.id, name: self.name, breadcrumb: breadcrumb}
  end
end
