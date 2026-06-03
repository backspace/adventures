defmodule Registrations.Poles.Regions do
  @moduledoc """
  Context for regions: nestable groupings that contribute accessibility
  tags and entry instructions to the puzzlets within them. The
  `inheritance_chain/1` helper walks a puzzlet's region up to the root and
  is the canonical source for what an author/player ultimately sees.
  """
  import Ecto.Query, warn: false

  alias Registrations.Poles.Puzzlet
  alias Registrations.Poles.Region
  alias Registrations.Repo

  def list_regions, do: Repo.all(from(r in Region, order_by: [asc: r.name]))

  def get_region(id), do: Repo.get(Region, id)

  def get_region!(id), do: Repo.get!(Region, id)

  @doc """
  Search by case-insensitive substring on name. Returns up to `limit`
  matches, ordered alphabetically.
  """
  def search_regions(query, opts \\ [])

  def search_regions(nil, opts), do: search_regions("", opts)

  def search_regions(query, opts) when is_binary(query) do
    limit = Keyword.get(opts, :limit, 20)
    pattern = "%" <> query <> "%"

    Region
    |> where([r], ilike(r.name, ^pattern))
    |> order_by([r], asc: r.name)
    |> limit(^limit)
    |> Repo.all()
  end

  def create_region(attrs) do
    %Region{}
    |> Region.changeset(attrs)
    |> Repo.insert()
  end

  def update_region(%Region{} = region, attrs) do
    region
    |> Region.changeset(attrs)
    |> reject_ancestor_cycle()
    |> Repo.update()
  end

  @doc """
  Deletes the region if no puzzlets reference it and it has no children.
  Otherwise returns `{:error, :in_use}` so callers can show a meaningful
  message rather than a foreign-key violation.
  """
  def delete_region(%Region{} = region) do
    if region_in_use?(region.id) do
      {:error, :in_use}
    else
      Repo.delete(region)
    end
  end

  defp region_in_use?(region_id) do
    has_child? =
      Region
      |> where([r], r.parent_region_id == ^region_id)
      |> Repo.exists?()

    has_puzzlet? =
      Puzzlet
      |> where([p], p.region_id == ^region_id)
      |> Repo.exists?()

    has_child? or has_puzzlet?
  end

  @doc """
  Returns the region's ancestor chain ordered top-most-first (root → self).
  Includes the region itself as the last element.
  """
  def ancestor_chain(nil), do: []

  def ancestor_chain(%Region{} = region) do
    # walk_up already prepends parents to the accumulator, so the result is
    # already ordered root → self.
    walk_up(region, [])
  end

  def ancestor_chain(region_id) when is_binary(region_id) do
    case get_region(region_id) do
      nil -> []
      region -> ancestor_chain(region)
    end
  end

  defp walk_up(nil, acc), do: acc

  defp walk_up(%Region{} = region, acc) do
    if region.parent_region_id do
      parent = Repo.get(Region, region.parent_region_id)
      walk_up(parent, [region | acc])
    else
      [region | acc]
    end
  end

  # Refuse a parent_region_id whose ancestor chain already contains this
  # region — that would create a cycle and infinite-loop the walk.
  defp reject_ancestor_cycle(changeset) do
    case {Ecto.Changeset.get_field(changeset, :id),
          Ecto.Changeset.get_change(changeset, :parent_region_id)} do
      {nil, _} ->
        changeset

      {_, nil} ->
        changeset

      {self_id, new_parent_id} ->
        if would_create_cycle?(self_id, new_parent_id) do
          Ecto.Changeset.add_error(changeset, :parent_region_id, "would create a cycle")
        else
          changeset
        end
    end
  end

  defp would_create_cycle?(self_id, candidate_parent_id) do
    candidate_parent_id == self_id or
      Enum.any?(
        ancestor_chain(candidate_parent_id),
        fn r -> r.id == self_id end
      )
  end

  @doc """
  Builds the inherited-accessibility view for a puzzlet's region (or any
  region) and returns:

    * `:inherited_tags` — flat, deduped union of every ancestor's tags
    * `:inherited_stanzas` — list of stanzas, top-most ancestor first,
      omitting empty rows. Each stanza is
      `%{source: name, notes: ..., entry_instructions: ...}`.

  Callers compose this with the puzzlet's own tags/notes when rendering.
  """
  def inherited(nil), do: %{inherited_tags: [], inherited_stanzas: []}

  def inherited(%Region{} = region), do: inherited(ancestor_chain(region))

  def inherited(region_id) when is_binary(region_id),
    do: inherited(ancestor_chain(region_id))

  def inherited(chain) when is_list(chain) do
    tags =
      chain
      |> Enum.flat_map(& &1.accessibility_tags)
      |> Enum.uniq()

    stanzas =
      chain
      |> Enum.map(fn r ->
        %{
          source: r.name,
          notes: r.accessibility_notes,
          entry_instructions: r.entry_instructions
        }
      end)
      |> Enum.reject(&empty_stanza?/1)

    %{inherited_tags: tags, inherited_stanzas: stanzas}
  end

  defp empty_stanza?(%{notes: notes, entry_instructions: instr}) do
    is_nil_or_blank?(notes) and is_nil_or_blank?(instr)
  end

  defp is_nil_or_blank?(nil), do: true
  defp is_nil_or_blank?(s) when is_binary(s), do: String.trim(s) == ""

  @doc """
  Convenience shape for puzzlet JSON renderers. Returns a map that can be
  merged into the puzzlet payload to expose region linkage and inherited
  accessibility info. Safe to call when `puzzlet.region_id` is nil.
  """
  def puzzlet_inheritance_payload(%Puzzlet{region_id: region_id}) do
    %{inherited_tags: tags, inherited_stanzas: stanzas} = inherited(region_id)

    %{
      region_id: region_id,
      inherited_tags: tags,
      inherited_stanzas: stanzas
    }
  end
end
