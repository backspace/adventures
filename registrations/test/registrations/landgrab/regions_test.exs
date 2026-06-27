defmodule Registrations.Landgrab.RegionsTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Landgrab.Region
  alias Registrations.Landgrab.Regions

  describe "ancestor_chain/1" do
    test "returns just the region itself when it has no parent" do
      r = insert(:poles_region, name: "Top")

      assert [%Region{id: id, name: "Top"}] = Regions.ancestor_chain(r)
      assert id == r.id
    end

    test "returns root → self for a multi-level chain" do
      a = insert(:poles_region, name: "777 Main St")
      b = insert(:poles_region, name: "4th floor", parent_region_id: a.id)
      c = insert(:poles_region, name: "Server room", parent_region_id: b.id)

      names = c |> Regions.ancestor_chain() |> Enum.map(& &1.name)
      assert names == ["777 Main St", "4th floor", "Server room"]
    end

    test "accepts a region_id string" do
      a = insert(:poles_region, name: "Top")
      b = insert(:poles_region, name: "Child", parent_region_id: a.id)

      names = b.id |> Regions.ancestor_chain() |> Enum.map(& &1.name)
      assert names == ["Top", "Child"]
    end

    test "returns [] for nil" do
      assert Regions.ancestor_chain(nil) == []
    end
  end

  describe "inherited/1" do
    test "unions tags across ancestors and dedupes" do
      a = insert(:poles_region, name: "Building", accessibility_tags: ["stairs", "narrow"])
      b = insert(:poles_region, name: "Floor", parent_region_id: a.id, accessibility_tags: ["narrow", "low-light"])

      assert %{inherited_tags: tags} = Regions.inherited(b.id)
      assert Enum.sort(tags) == ["low-light", "narrow", "stairs"]
    end

    test "orders stanzas top-most first and skips empty rows" do
      a = insert(:poles_region, name: "Building", accessibility_notes: "Keycard after 6pm")
      b = insert(:poles_region, name: "Floor", parent_region_id: a.id)

      c =
        insert(:poles_region,
          name: "Room",
          parent_region_id: b.id,
          entry_instructions: "Knock twice"
        )

      %{inherited_stanzas: stanzas} = Regions.inherited(c.id)

      # Floor has no notes/instructions — it's filtered out.
      assert [
               %{source: "Building", notes: "Keycard after 6pm", entry_instructions: nil},
               %{source: "Room", notes: nil, entry_instructions: "Knock twice"}
             ] = stanzas
    end

    test "returns empties for a nil region_id" do
      assert Regions.inherited(nil) == %{inherited_tags: [], inherited_stanzas: []}
    end
  end

  describe "update_region/2 cycle prevention" do
    test "rejects setting parent to a descendant" do
      a = insert(:poles_region, name: "A")
      b = insert(:poles_region, name: "B", parent_region_id: a.id)

      # Try to make A a child of B — would form A ↔ B cycle.
      {:error, changeset} = Regions.update_region(a, %{parent_region_id: b.id})

      assert {"would create a cycle", _} = changeset.errors[:parent_region_id]
    end

    test "rejects self-parent on existing record" do
      a = insert(:poles_region, name: "A")

      {:error, changeset} = Regions.update_region(a, %{parent_region_id: a.id})

      assert {_, _} = changeset.errors[:parent_region_id]
    end
  end

  describe "delete_region/1" do
    test "refuses when sub-regions exist" do
      a = insert(:poles_region, name: "A")
      _b = insert(:poles_region, name: "B", parent_region_id: a.id)

      assert {:error, :in_use} = Regions.delete_region(a)
    end

    test "refuses when puzzlets reference it" do
      r = insert(:poles_region, name: "R")
      _p = insert(:puzzlet, region_id: r.id)

      assert {:error, :in_use} = Regions.delete_region(r)
    end

    test "succeeds for an unused region" do
      r = insert(:poles_region, name: "R")
      assert {:ok, _} = Regions.delete_region(r)
      refute Regions.get_region(r.id)
    end
  end

  describe "search_regions/2" do
    test "matches case-insensitive substring" do
      _a = insert(:poles_region, name: "777 Main St")
      _b = insert(:poles_region, name: "Library annex")

      names = "main" |> Regions.search_regions() |> Enum.map(& &1.name)
      assert "777 Main St" in names
      refute "Library annex" in names
    end
  end
end
