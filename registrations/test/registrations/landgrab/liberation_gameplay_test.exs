defmodule Registrations.Landgrab.LiberationGameplayTest do
  @moduledoc """
  Phase 1 of the liberation arc: the capture inversion. A team that
  accepted Bedab's invitation liberates owned stakes (returned to
  no-owner) instead of capturing; everyone else keeps the capture game,
  including re-seizing liberated stakes from the per-team pool.
  """
  use Registrations.DataCase, async: true

  import Registrations.Factory

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Notification
  alias Registrations.Landgrab.PlayerStrings

  defp accept!(team),
    do: team |> Ecto.Changeset.change(liberation_response: "accepted") |> Repo.update!()

  defp decline!(team),
    do: team |> Ecto.Changeset.change(liberation_response: "declined") |> Repo.update!()

  defp ago(seconds),
    do: DateTime.utc_now() |> DateTime.add(-seconds, :second) |> DateTime.truncate(:second)

  describe "team_liberation_stance/1" do
    test "liberator only once accepted; everyone else captures" do
      accepted = insert(:team) |> accept!()
      declined = insert(:team) |> decline!()
      undecided = insert(:team)

      assert Landgrab.team_liberation_stance(accepted.id) == :liberator
      assert Landgrab.team_liberation_stance(declined.id) == :capturer
      assert Landgrab.team_liberation_stance(undecided.id) == :capturer
      assert Landgrab.team_liberation_stance(nil) == :capturer
    end
  end

  describe "serving a liberator at an owned stake" do
    test "a fully-captured (locked) stake serves from the liberator's pool" do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, status: :validated)
      owner = insert(:team)
      insert(:ownership_event, puzzlet: puzzlet, team: owner, pole_id: pole.id)

      liberator = insert(:team) |> accept!()
      capturer = insert(:team)

      # Global consume-once still locks out the capture side...
      assert Landgrab.active_puzzlet_for_pole(pole, nil, [], capturer.id) == nil
      # ...but the liberator is served the relic they haven't solved.
      served = Landgrab.active_puzzlet_for_pole(pole, nil, [], liberator.id)
      assert served && served.id == puzzlet.id
    end

    test "the map lock is per-liberator, not the global fully-captured lock" do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, status: :validated)
      owner = insert(:team)
      insert(:ownership_event, puzzlet: puzzlet, team: owner, pole_id: pole.id)

      liberator = insert(:team) |> accept!()
      capturer = insert(:team)

      locked_for = fn team_id ->
        Landgrab.list_poles_with_state(team_id)
        |> Enum.find(&(&1.pole.id == pole.id))
        |> Map.fetch!(:locked?)
      end

      # Globally "fully captured" — locked for the capture side...
      assert locked_for.(capturer.id) == true
      # ...but the liberator still has an unsolved relic here, so the icon must
      # NOT read locked for them (it tracks what they can still free).
      refute locked_for.(liberator.id)

      # Once they've freed it (solved that relic), it locks for them too.
      insert(:ownership_event,
        kind: "liberate",
        puzzlet: puzzlet,
        team: liberator,
        pole_id: pole.id
      )

      assert locked_for.(liberator.id) == true
    end

    test "scanning their OWN stake serves rather than refusing already_owner" do
      pole = insert(:pole)
      p1 = insert(:puzzlet, pole: pole, status: :validated, difficulty: 1)
      insert(:puzzlet, pole: pole, status: :validated, difficulty: 2)
      liberator = insert(:team) |> accept!()
      insert(:user, team_id: liberator.id)
      # Their own earlier capture — fair game to liberate.
      insert(:ownership_event, puzzlet: p1, team: liberator, pole_id: pole.id, inserted_at: ago(60))

      assert {:ok, payload} = Landgrab.scan_payload(pole.barcode, liberator.id)
      # Served the relic they DIDN'T solve; their captured one is spent credit.
      assert payload.active_puzzlet && payload.active_puzzlet.id != p1.id
    end

    test "never-claimed ground still serves a liberator — they can work any stake" do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, status: :validated)
      liberator = insert(:team) |> accept!()

      assert {:ok, payload} = Landgrab.scan_payload(pole.barcode, liberator.id)
      assert payload.active_puzzlet && payload.active_puzzlet.id == puzzlet.id
    end

    test "an already-liberated stake still serves — the zone won't change, but the liberator can keep solving its puzzlets" do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, status: :validated)
      owner = insert(:team)
      insert(:ownership_event, puzzlet: puzzlet, team: owner, pole_id: pole.id, inserted_at: ago(120))

      other_liberator = insert(:team) |> accept!()

      insert(:ownership_event,
        kind: "liberate",
        puzzlet: puzzlet,
        team: other_liberator,
        pole_id: pole.id,
        inserted_at: ago(60)
      )

      # A fresh liberator walking up to already-freed ground isn't refused. It
      # stays freed, and per-team serving offers the relic they haven't solved.
      liberator = insert(:team) |> accept!()
      assert {:ok, payload} = Landgrab.scan_payload(pole.barcode, liberator.id)
      assert payload.active_puzzlet && payload.active_puzzlet.id == puzzlet.id
      assert Landgrab.pole_liberated?(pole)
    end
  end

  describe "record_attempt/4 as a liberator" do
    setup do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, status: :validated, answer: "x")
      owner = insert(:team)
      insert(:ownership_event, puzzlet: puzzlet, team: owner, pole_id: pole.id, inserted_at: ago(60))

      liberator = insert(:team) |> accept!()
      user = insert(:user, team_id: liberator.id)
      insert(:team_puzzlet, team: liberator, puzzlet: puzzlet, pole: pole)

      %{pole: pole, puzzlet: puzzlet, owner: owner, liberator: liberator, user: user}
    end

    test "a correct answer liberates: no owner, liberated state, solve credit", ctx do
      assert {:ok, %{result: :liberated, capture: event}} =
               Landgrab.record_attempt(ctx.puzzlet, ctx.liberator.id, ctx.user.id, "x")

      assert event.kind == "liberate"
      assert Landgrab.current_owner_team_id_for_pole(ctx.pole) == nil
      assert Landgrab.pole_liberated?(ctx.pole)
      # Solve credit: the relic is theirs, never re-served to them.
      assert MapSet.member?(Landgrab.team_solved_puzzlet_ids(ctx.liberator.id), ctx.puzzlet.id)
    end

    test "the previous owner is told their stake was freed, not captured", ctx do
      {:ok, _} = Landgrab.record_attempt(ctx.puzzlet, ctx.liberator.id, ctx.user.id, "x")

      notification =
        Repo.one(
          from(n in Notification,
            where: n.type == "pole_lost" and n.recipient_team_id == ^ctx.owner.id
          )
        )

      assert notification
      # Freed reads as "unclaimed" in player copy (a stake returned to the
      # commons), never "captured".
      assert notification.body =~ "unclaimed"
      refute notification.body =~ "captured"
    end

    test "liberating their own stake works and stays quiet", ctx do
      # Rebind ownership to the liberator's own team (newer than setup's).
      insert(:ownership_event,
        puzzlet: insert(:puzzlet, pole: ctx.pole, status: :validated),
        team: ctx.liberator,
        pole_id: ctx.pole.id,
        inserted_at: ago(30)
      )

      assert {:ok, %{result: :liberated}} =
               Landgrab.record_attempt(ctx.puzzlet, ctx.liberator.id, ctx.user.id, "x")

      assert Landgrab.pole_liberated?(ctx.pole)
      # No pole_lost noise about their own deliberate act.
      assert Repo.aggregate(
               from(n in Notification,
                 where: n.type == "pole_lost" and n.recipient_team_id == ^ctx.liberator.id
               ),
               :count
             ) == 0
    end

    test "freed by someone else mid-solve → the answer still counts; the zone was already free and stays free", ctx do
      other = insert(:team) |> accept!()

      insert(:ownership_event,
        kind: "liberate",
        puzzlet: insert(:puzzlet, pole: ctx.pole, status: :validated),
        team: other,
        pole_id: ctx.pole.id,
        inserted_at: ago(10)
      )

      assert {:ok, %{result: :liberated}} =
               Landgrab.record_attempt(ctx.puzzlet, ctx.liberator.id, ctx.user.id, "x")

      # Ownership is unchanged — already freed, still freed — but the
      # liberator's solve is credited so the puzzlet is theirs, done.
      assert Landgrab.current_owner_team_id_for_pole(ctx.pole) == nil
      assert Landgrab.pole_liberated?(ctx.pole)
      assert MapSet.member?(Landgrab.team_solved_puzzlet_ids(ctx.liberator.id), ctx.puzzlet.id)
    end

    test "solving never-claimed ground records credit and leaves it unclaimed", ctx do
      fresh = insert(:pole)
      relic = insert(:puzzlet, pole: fresh, status: :validated, answer: "y")
      insert(:team_puzzlet, team: ctx.liberator, puzzlet: relic, pole: fresh)

      assert {:ok, %{result: :liberated}} =
               Landgrab.record_attempt(relic, ctx.liberator.id, ctx.user.id, "y")

      # Never had an owner, still has none — but the solve is credited.
      assert Landgrab.current_owner_team_id_for_pole(fresh) == nil
      assert Landgrab.pole_liberated?(fresh)
      assert MapSet.member?(Landgrab.team_solved_puzzlet_ids(ctx.liberator.id), relic.id)
    end

    test "a wrong answer is just a wrong answer", ctx do
      assert {:ok, %{result: :incorrect}} =
               Landgrab.record_attempt(ctx.puzzlet, ctx.liberator.id, ctx.user.id, "nope")

      assert Landgrab.current_owner_team_id_for_pole(ctx.pole) == ctx.owner.id
      refute Landgrab.pole_liberated?(ctx.pole)
    end
  end

  describe "re-seizing a liberated stake (reversibility)" do
    setup do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, status: :validated, answer: "x")
      first_owner = insert(:team)
      insert(:ownership_event, puzzlet: puzzlet, team: first_owner, pole_id: pole.id, inserted_at: ago(120))

      liberator = insert(:team) |> accept!()

      insert(:ownership_event,
        kind: "liberate",
        puzzlet: puzzlet,
        team: liberator,
        pole_id: pole.id,
        inserted_at: ago(60)
      )

      reseizer = insert(:team)
      user = insert(:user, team_id: reseizer.id)

      %{pole: pole, puzzlet: puzzlet, reseizer: reseizer, user: user, liberator: liberator}
    end

    test "a capturer is served from their per-team pool at a liberated stake", ctx do
      served = Landgrab.active_puzzlet_for_pole(ctx.pole, nil, [], ctx.reseizer.id)
      assert served && served.id == ctx.puzzlet.id
    end

    test "solving re-seizes: owned again, not liberated", ctx do
      insert(:team_puzzlet, team: ctx.reseizer, puzzlet: ctx.puzzlet, pole: ctx.pole)

      assert {:ok, %{result: :captured}} =
               Landgrab.record_attempt(ctx.puzzlet, ctx.reseizer.id, ctx.user.id, "x")

      assert Landgrab.current_owner_team_id_for_pole(ctx.pole) == ctx.reseizer.id
      refute Landgrab.pole_liberated?(ctx.pole)
    end

    test "the liberating team can't be re-served the relic they freed", ctx do
      # Their liberate event is solve credit, and re-capture would need a
      # relic they haven't solved — here there is none.
      assert Landgrab.active_puzzlet_for_pole(ctx.pole, nil, [], ctx.liberator.id) == nil
    end
  end

  describe "the capture side is unchanged" do
    test "a decliner at their own stake is still refused already_owner" do
      pole = insert(:pole)
      p1 = insert(:puzzlet, pole: pole, status: :validated, difficulty: 1)
      insert(:puzzlet, pole: pole, status: :validated, difficulty: 2)
      decliner = insert(:team) |> decline!()
      insert(:user, team_id: decliner.id)
      insert(:ownership_event, puzzlet: p1, team: decliner, pole_id: pole.id, inserted_at: ago(60))

      assert {:error, :already_owner, _pole} = Landgrab.scan_payload(pole.barcode, decliner.id)
    end

    test "an owned, part-captured stake still serves attackers globally" do
      pole = insert(:pole)
      p1 = insert(:puzzlet, pole: pole, status: :validated, difficulty: 1)
      p2 = insert(:puzzlet, pole: pole, status: :validated, difficulty: 2)
      owner = insert(:team)
      insert(:ownership_event, puzzlet: p1, team: owner, pole_id: pole.id)

      attacker = insert(:team)
      served = Landgrab.active_puzzlet_for_pole(pole, nil, [], attacker.id)
      assert served && served.id == p2.id
    end
  end

  describe "Sabuk's first-liberation outrage" do
    # A liberator with a member, and an owned pole they can free.
    defp owned_pole_for(answer) do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, status: :validated, answer: answer)
      insert(:ownership_event, puzzlet: puzzlet, team: insert(:team), pole_id: pole.id, inserted_at: ago(60))
      {pole, puzzlet}
    end

    defp liberate_first_pole(team, answer) do
      {pole, puzzlet} = owned_pole_for(answer)
      user = insert(:user, team_id: team.id)
      insert(:team_puzzlet, team: team, puzzlet: puzzlet, pole: pole)
      assert {:ok, %{result: :liberated}} = Landgrab.record_attempt(puzzlet, team.id, user.id, answer)
    end

    defp sabuk_messages(team_id) do
      Repo.all(
        from(n in Notification,
          where: n.recipient_team_id == ^team_id and n.type == "message",
          order_by: n.inserted_at
        )
      )
    end

    test "the first unclaim triggers a Sabuk message to that team" do
      team = insert(:team) |> accept!()
      liberate_first_pole(team, "x")

      assert [msg] = sabuk_messages(team.id)
      assert msg.metadata["sender_name"] == "Sabuk"
      assert msg.body == PlayerStrings.sabuk_first_liberation_body(0)
    end

    test "a team's later unclaims send no further Sabuk message" do
      team = insert(:team) |> accept!()
      user = insert(:user, team_id: team.id)

      {pole1, pz1} = owned_pole_for("a")
      insert(:team_puzzlet, team: team, puzzlet: pz1, pole: pole1)
      {:ok, _} = Landgrab.record_attempt(pz1, team.id, user.id, "a")

      {pole2, pz2} = owned_pole_for("b")
      insert(:team_puzzlet, team: team, puzzlet: pz2, pole: pole2)
      {:ok, %{result: :liberated}} = Landgrab.record_attempt(pz2, team.id, user.id, "b")

      # Still just the one, from the first unclaim.
      assert length(sabuk_messages(team.id)) == 1
    end

    test "different teams cycle through the set in defection order" do
      a = insert(:team) |> accept!()
      liberate_first_pole(a, "a")

      b = insert(:team) |> accept!()
      liberate_first_pole(b, "b")

      c = insert(:team) |> accept!()
      liberate_first_pole(c, "c")

      assert [ma] = sabuk_messages(a.id)
      assert [mb] = sabuk_messages(b.id)
      assert [mc] = sabuk_messages(c.id)

      assert ma.body == PlayerStrings.sabuk_first_liberation_body(0)
      assert mb.body == PlayerStrings.sabuk_first_liberation_body(1)
      assert mc.body == PlayerStrings.sabuk_first_liberation_body(2)
      # All distinct — the point of cycling.
      assert Enum.uniq([ma.body, mb.body, mc.body]) |> length() == 3
    end
  end
end
