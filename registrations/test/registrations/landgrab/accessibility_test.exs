defmodule Registrations.Landgrab.AccessibilityTest do
  use Registrations.DataCase, async: true

  import Registrations.Factory

  alias Registrations.Landgrab.Accessibility

  describe "compatible?/2 and conflicting_tags/2" do
    test "disjoint needs and demands are compatible" do
      assert Accessibility.compatible?(["stairs"], ["dim_lighting"])
      assert Accessibility.conflicting_tags(["stairs"], ["dim_lighting"]) == []
    end

    test "overlapping needs and demands conflict" do
      refute Accessibility.compatible?(["stairs", "heights"], ["stairs"])
      assert Accessibility.conflicting_tags(["stairs", "heights"], ["stairs"]) == ["stairs"]
    end

    test "empty needs are compatible with anything" do
      assert Accessibility.compatible?([], ["stairs", "heights"])
      assert Accessibility.compatible?(nil, ["stairs"])
    end

    test "accepts MapSets as well as lists" do
      assert Accessibility.compatible?(MapSet.new(["stairs"]), MapSet.new(["heights"]))
      refute Accessibility.compatible?(MapSet.new(["stairs"]), ["stairs"])
    end

    test "conflicting tags are sorted and deduped" do
      assert Accessibility.conflicting_tags(["heights", "stairs"], ["stairs", "heights"]) ==
               ["heights", "stairs"]
    end
  end

  describe "effective_tags/1 (own tags ∪ inherited region tags)" do
    test "a puzzlet with no region uses only its own tags" do
      puzzlet = insert(:puzzlet, accessibility_tags: ["heights"])
      assert Accessibility.effective_tags(puzzlet) == MapSet.new(["heights"])
    end

    test "inherits tags from the region ancestor chain" do
      grandparent = insert(:poles_region, accessibility_tags: ["stairs"])
      parent = insert(:poles_region, parent_region_id: grandparent.id, accessibility_tags: ["steep"])
      puzzlet = insert(:puzzlet, region_id: parent.id, accessibility_tags: ["heights"])

      # own "heights" + parent "steep" + grandparent "stairs"
      assert Accessibility.effective_tags(puzzlet) ==
               MapSet.new(["heights", "steep", "stairs"])
    end

    test "a no-tag puzzlet in a tagged region takes the region's tags" do
      region = insert(:poles_region, accessibility_tags: ["stairs"])
      puzzlet = insert(:puzzlet, region_id: region.id)
      assert Accessibility.effective_tags(puzzlet) == MapSet.new(["stairs"])
    end
  end

  describe "doable?/2 and doable_puzzlets/2" do
    test "a puzzlet in a stairs region is not doable for a no-stairs player" do
      region = insert(:poles_region, accessibility_tags: ["stairs"])
      puzzlet = insert(:puzzlet, region_id: region.id)
      refute Accessibility.doable?(puzzlet, ["stairs"])
      assert Accessibility.doable?(puzzlet, ["heights"])
    end

    test "filters a mixed list to the doable ones" do
      stairs = insert(:poles_region, accessibility_tags: ["stairs"])
      step_free = insert(:poles_region, accessibility_tags: [])
      hard = insert(:puzzlet, region_id: stairs.id)
      easy = insert(:puzzlet, region_id: step_free.id)

      doable = Accessibility.doable_puzzlets([hard, easy], ["stairs"])
      assert Enum.map(doable, & &1.id) == [easy.id]
    end
  end

  describe "prohibitive?/2" do
    test "an empty puzzlet list is never prohibitive" do
      refute Accessibility.prohibitive?([], ["stairs"])
    end

    test "prohibitive when every remaining puzzlet conflicts" do
      stairs = insert(:poles_region, accessibility_tags: ["stairs"])
      a = insert(:puzzlet, region_id: stairs.id)
      b = insert(:puzzlet, region_id: stairs.id)
      assert Accessibility.prohibitive?([a, b], ["stairs"])
    end

    test "not prohibitive when at least one puzzlet is doable" do
      stairs = insert(:poles_region, accessibility_tags: ["stairs"])
      step_free = insert(:poles_region, accessibility_tags: [])
      hard = insert(:puzzlet, region_id: stairs.id)
      easy = insert(:puzzlet, region_id: step_free.id)
      refute Accessibility.prohibitive?([hard, easy], ["stairs"])
    end
  end

  describe "team_needs/1 (union of members' needs)" do
    test "nil team has no needs" do
      assert Accessibility.team_needs(nil) == MapSet.new()
    end

    test "unions every member's declared needs" do
      team = insert(:team)
      insert(:user, team_id: team.id, accessibility_tags: ["stairs"])
      insert(:user, team_id: team.id, accessibility_tags: ["heights", "stairs"])
      insert(:user, team_id: team.id, accessibility_tags: [])

      assert Accessibility.team_needs(team.id) == MapSet.new(["stairs", "heights"])
    end

    test "a stake doable by one member but not another is prohibitive for the team" do
      team = insert(:team)
      insert(:user, team_id: team.id, accessibility_tags: [])
      insert(:user, team_id: team.id, accessibility_tags: ["stairs"])

      stairs = insert(:poles_region, accessibility_tags: ["stairs"])
      only_puzzlet = insert(:puzzlet, region_id: stairs.id)

      needs = Accessibility.team_needs(team.id)
      # The stairs-averse member rules out the only puzzlet, so it's prohibitive
      # for the whole team even though the other member could do it.
      assert Accessibility.prohibitive?([only_puzzlet], needs)
    end
  end
end
