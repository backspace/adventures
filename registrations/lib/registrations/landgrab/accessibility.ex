defmodule Registrations.Landgrab.Accessibility do
  @moduledoc """
  Matching a stake's puzzlets against a player's / team's accessibility needs.

  This is the pure computation layer for accessibility routing — it decides
  *whether* a puzzlet suits someone; it does not select, serve, capture, or
  render anything. Later steps read it:

    * the map pre-warning (a pole prohibitive for the team),
    * the on-scan conflict choice (surface, don't decide),
    * the accommodation claim (a pole with nothing doable).

  ## The tag model

  Tags are keys from `Registrations.Landgrab.AccessibilityTag`, used in two
  senses that share a vocabulary:

    * A **player's** `accessibility_tags` are *avoidances* — `"stairs"` means
      "no stairs."
    * A **puzzlet's** tags are *demands* — `"stairs"` means "this involves
      stairs." A puzzlet's demands are its own `accessibility_tags` plus every
      tag inherited from its region's ancestor chain (`Regions.inherited/1`) —
      the union is its **effective tags**.

  A puzzlet **suits** a player iff their needs and its effective tags are
  disjoint. Any overlap (they avoid `"stairs"`, it involves `"stairs"`) is a
  conflict.

  ## Whose needs

  A stake is captured by a team, so the team basis is the **union** of its
  members' needs: a puzzlet the whole team can engage together is one disjoint
  from that union (if disjoint from the union, it's disjoint from each member).
  This makes any single member's need able to rule a puzzlet out — matching the
  intent that a stake is flagged prohibitive if it would exclude *anyone*.
  """

  import Ecto.Query

  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.Regions
  alias Registrations.Repo

  @doc """
  A puzzlet's effective accessibility demands: its own tags unioned with the
  tags inherited from its region's ancestor chain. Returns a `MapSet`.
  """
  @spec effective_tags(Puzzlet.t()) :: MapSet.t(String.t())
  def effective_tags(%Puzzlet{} = puzzlet) do
    inherited = Regions.inherited(puzzlet.region_id).inherited_tags
    to_set(puzzlet.accessibility_tags) |> MapSet.union(to_set(inherited))
  end

  @doc """
  True when `needs` (a player's or team's avoidances) don't conflict with
  `demands` (a puzzlet's effective tags) — i.e. the sets are disjoint. Accepts
  lists or MapSets for either argument.
  """
  @spec compatible?(Enumerable.t(), Enumerable.t()) :: boolean()
  def compatible?(needs, demands), do: MapSet.disjoint?(to_set(needs), to_set(demands))

  @doc """
  The tags that actually conflict between `needs` and `demands` — the
  intersection. For phrasing a warning ("involves stairs") without leaking the
  whole tag set. Returns a sorted list.
  """
  @spec conflicting_tags(Enumerable.t(), Enumerable.t()) :: [String.t()]
  def conflicting_tags(needs, demands) do
    MapSet.intersection(to_set(needs), to_set(demands)) |> Enum.sort()
  end

  @doc """
  True when a single puzzlet suits the given needs (its effective tags are
  disjoint from them). Convenience over `effective_tags/1` + `compatible?/2`.
  """
  @spec doable?(Puzzlet.t(), Enumerable.t()) :: boolean()
  def doable?(%Puzzlet{} = puzzlet, needs), do: compatible?(needs, effective_tags(puzzlet))

  @doc """
  The subset of `puzzlets` that suit `needs`, order preserved.
  """
  @spec doable_puzzlets([Puzzlet.t()], Enumerable.t()) :: [Puzzlet.t()]
  def doable_puzzlets(puzzlets, needs) when is_list(puzzlets) do
    Enum.filter(puzzlets, &doable?(&1, needs))
  end

  @doc """
  Whether a stake is **prohibitive** for the given needs: none of the supplied
  (already uncaptured, playable) puzzlets suits them. With team-union needs this
  means no puzzlet the whole team can engage together remains — the map-flag
  condition. An empty puzzlet list is NOT prohibitive (nothing to be excluded
  from — that's a fully-captured / empty stake, handled elsewhere).
  """
  @spec prohibitive?([Puzzlet.t()], Enumerable.t()) :: boolean()
  def prohibitive?([], _needs), do: false
  def prohibitive?(puzzlets, needs) when is_list(puzzlets),
    do: not Enum.any?(puzzlets, &doable?(&1, needs))

  @doc """
  Union of a team's members' accessibility needs, as a `MapSet`. Empty for a nil
  team or a team whose members declared nothing.
  """
  @spec team_needs(String.t() | nil) :: MapSet.t(String.t())
  def team_needs(nil), do: MapSet.new()

  def team_needs(team_id) when is_binary(team_id) do
    RegistrationsWeb.User
    |> where([u], u.team_id == ^team_id)
    |> select([u], u.accessibility_tags)
    |> Repo.all()
    |> Enum.reduce(MapSet.new(), fn tags, acc -> MapSet.union(acc, to_set(tags)) end)
  end

  # Normalise nil / list / MapSet of tags to a MapSet.
  defp to_set(nil), do: MapSet.new()
  defp to_set(%MapSet{} = set), do: set
  defp to_set(tags) when is_list(tags), do: MapSet.new(tags)
end
