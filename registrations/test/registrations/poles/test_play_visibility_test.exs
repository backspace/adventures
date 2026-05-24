defmodule Registrations.Poles.TestPlayVisibilityTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Poles
  alias Registrations.Poles.Scope
  alias Registrations.Poles.Validations.PoleValidation
  alias Registrations.Poles.Validations.PuzzletValidation
  alias Registrations.Repo

  describe "Scope.test/2 with visibility_user_id" do
    setup do
      author = insert(:user, email: "author#{u()}@example.com")
      assigner = insert(:user, email: "boss#{u()}@example.com")
      alice = insert(:user, email: "alice#{u()}@example.com")
      bob = insert(:user, email: "bob#{u()}@example.com")

      # Three poles with one puzzlet each, authored by `author`.
      a_pole = insert(:pole, creator: author, status: :validated, barcode: "BC-A#{u()}")
      b_pole = insert(:pole, creator: author, status: :validated, barcode: "BC-B#{u()}")
      c_pole = insert(:pole, creator: author, status: :validated, barcode: "BC-C#{u()}")

      # Puzzlets need a location in test scope so the proximity-based
      # `test_active_puzzlet` rotation can find them.
      a_puzzlet =
        insert(:puzzlet,
          pole: a_pole,
          creator: author,
          status: :validated,
          latitude: a_pole.latitude,
          longitude: a_pole.longitude
        )

      b_puzzlet =
        insert(:puzzlet,
          pole: b_pole,
          creator: author,
          status: :validated,
          latitude: b_pole.latitude,
          longitude: b_pole.longitude
        )

      c_puzzlet =
        insert(:puzzlet,
          pole: c_pole,
          creator: author,
          status: :validated,
          latitude: c_pole.latitude,
          longitude: c_pole.longitude
        )

      # Alice is assigned to validate pole A. Bob is assigned to pole B's
      # puzzlet. Neither has any relationship to pole C.
      Repo.insert!(%PoleValidation{
        pole_id: a_pole.id,
        validator_id: alice.id,
        assigned_by_id: assigner.id
      })

      Repo.insert!(%PuzzletValidation{
        puzzlet_id: b_puzzlet.id,
        validator_id: bob.id,
        assigned_by_id: assigner.id
      })

      session = insert_test_session(alice)

      {:ok,
       author: author,
       alice: alice,
       bob: bob,
       a_pole: a_pole,
       b_pole: b_pole,
       c_pole: c_pole,
       a_puzzlet: a_puzzlet,
       b_puzzlet: b_puzzlet,
       c_puzzlet: c_puzzlet,
       session: session}
    end

    test "validator sees only poles they created or are assigned (directly or via puzzlet)",
         %{alice: alice, bob: bob, a_pole: a_pole, b_pole: b_pole, c_pole: c_pole, session: session} do
      alice_scope = Scope.test(session.id, visibility_user_id: alice.id)
      bob_scope = Scope.test(session.id, visibility_user_id: bob.id)

      alice_pole_ids =
        Poles.list_poles_with_state(alice_scope) |> Enum.map(& &1.pole.id) |> MapSet.new()

      bob_pole_ids =
        Poles.list_poles_with_state(bob_scope) |> Enum.map(& &1.pole.id) |> MapSet.new()

      # Alice is assigned to pole A directly.
      assert MapSet.member?(alice_pole_ids, a_pole.id)
      refute MapSet.member?(alice_pole_ids, b_pole.id)
      refute MapSet.member?(alice_pole_ids, c_pole.id)

      # Bob is assigned to pole B's puzzlet — pole B is visible to him by extension.
      assert MapSet.member?(bob_pole_ids, b_pole.id)
      refute MapSet.member?(bob_pole_ids, a_pole.id)
      refute MapSet.member?(bob_pole_ids, c_pole.id)
    end

    test "unrestricted scope (supervisor/admin in test) sees all poles", %{session: session} do
      unrestricted = Scope.test(session.id)
      ids = Poles.list_poles_with_state(unrestricted) |> Enum.map(& &1.pole.id) |> MapSet.new()
      assert MapSet.size(ids) >= 3
    end

    test "scanning an invisible pole returns :not_found, not its existence",
         %{alice: alice, c_pole: c_pole, session: session} do
      scope = Scope.test(session.id, visibility_user_id: alice.id)

      assert {:error, :not_found} =
               Poles.scan_payload(c_pole.barcode, nil, alice.id, scope)
    end

    test "scanning a visible pole works in restricted scope",
         %{alice: alice, a_pole: a_pole, a_puzzlet: a_puzzlet, session: session} do
      scope = Scope.test(session.id, visibility_user_id: alice.id)

      assert {:ok, payload} = Poles.scan_payload(a_pole.barcode, nil, alice.id, scope)
      assert payload.pole.id == a_pole.id
      assert payload.active_puzzlet.id == a_puzzlet.id
    end

    test "in test scope, active_puzzlet picks from visible puzzlets regardless of pole linkage",
         %{alice: alice, bob: bob, a_pole: a_pole, b_pole: b_pole, a_puzzlet: a_puzzlet,
           b_puzzlet: b_puzzlet} do
      # During an alpha demo, puzzlets typically aren't wired to specific
      # poles yet — selection is by visibility + proximity, not pole_id.

      # Alice's only visible puzzlet is a_puzzlet (the one on the pole
      # she's assigned to). Scanning any of her visible poles returns it.
      alice_session = insert_test_session(alice)
      alice_scope = Scope.test(alice_session.id, visibility_user_id: alice.id)
      assert Poles.active_puzzlet_for_pole(a_pole, alice.id, alice_scope).id == a_puzzlet.id

      # Bob's only visible puzzlet is b_puzzlet. He doesn't see a_puzzlet
      # even on the pole where it physically lives, because visibility
      # filters it out.
      bob_session = insert_test_session(bob)
      bob_scope = Scope.test(bob_session.id, visibility_user_id: bob.id)
      assert Poles.active_puzzlet_for_pole(b_pole, bob.id, bob_scope).id == b_puzzlet.id
      assert Poles.active_puzzlet_for_pole(a_pole, bob.id, bob_scope).id == b_puzzlet.id
    end

    test "test scope picks from the 5 closest puzzlets (proximity), randomizing among them",
         %{author: author} do
      pole = insert(:pole, creator: author, status: :validated, barcode: "BC-prox#{u()}",
        latitude: 50.0, longitude: -100.0)

      # Seven validated puzzlets at varying distances. We expect the four
      # closest plus a fifth-tied to be the candidate pool; one of the two
      # far-away puzzlets must never be picked.
      close_puzzlets =
        for i <- 1..5 do
          insert(:puzzlet, creator: author, status: :validated,
            latitude: 50.0 + i * 0.001,
            longitude: -100.0)
        end

      far_a = insert(:puzzlet, creator: author, status: :validated,
        latitude: 60.0, longitude: -100.0)

      far_b = insert(:puzzlet, creator: author, status: :validated,
        latitude: 50.0, longitude: -120.0)

      session = insert_test_session(author)
      scope = Scope.test(session.id)

      close_ids = Enum.map(close_puzzlets, & &1.id) |> MapSet.new()

      # Run a bunch of rolls; only close puzzlets should ever come back.
      picks =
        for _ <- 1..30 do
          Poles.active_puzzlet_for_pole(pole, nil, scope).id
        end
        |> MapSet.new()

      assert MapSet.subset?(picks, close_ids)
      refute MapSet.member?(picks, far_a.id)
      refute MapSet.member?(picks, far_b.id)
    end

    test "real scope is never restricted by visibility_user_id (sanity)", %{c_pole: c_pole} do
      # Even the validator who can't see this pole in test scope can see it
      # in the real game (assuming they're authenticated). Visibility is a
      # test-play affordance, not a real-game permission.
      assert {:ok, _} = Poles.scan_payload(c_pole.barcode, nil, nil, Scope.real())
    end
  end

  # ─── helpers ─────────────────────────────────────────────────────────

  defp u, do: System.unique_integer([:positive])

  defp insert_test_session(user) do
    {:ok, session} = Poles.create_test_session(user, %{name: "test"})
    session
  end
end
