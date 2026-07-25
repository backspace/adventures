defmodule Registrations.Landgrab.SeedTest do
  @moduledoc """
  Smoke test for the scenario seeder. It doesn't assert exact fixtures —
  it asserts that each step still runs end-to-end through the real domain
  and produces the shape of state it promises. If a schema change or a
  gameplay/validation refactor breaks seeding, this fails here instead of
  mid-event. It also documents what each step is supposed to produce.
  """
  use Registrations.DataCase

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Attempt
  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Notification
  alias Registrations.Landgrab.OrganiserMessage
  alias Registrations.Landgrab.OwnershipEvent
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.Seed
  alias Registrations.Landgrab.TeamPuzzlet
  alias Registrations.Landgrab.Validations.PuzzletValidation
  alias RegistrationsWeb.Team
  alias RegistrationsWeb.User

  setup do
    # One author owns all the content. record_attempt rejects a puzzlet's
    # or pole's creator, so the author's team can never be a "player" —
    # which is exactly what the captures step relies on.
    author = insert(:user)

    # The two fixed accounts the validations step looks up by email.
    validator = insert(:user, email: Seed.validator_email())
    assigner = insert(:user, email: "b@chromatin.ca")

    # Teamless non-authors — the `teams` step turns these into playing teams.
    players = for _ <- 1..3, do: insert(:user)

    # Six validated, capturable puzzlets, each on its own pole.
    poles =
      for _ <- 1..6 do
        pole = insert(:pole, creator_id: author.id)
        insert(:puzzlet, pole: pole, creator_id: author.id, status: :validated, answer: "Foo")
        pole
      end

    %{author: author, validator: validator, assigner: assigner, players: players, poles: poles}
  end

  defp insert_event(attrs) do
    {:ok, event} =
      %Event{}
      |> Event.changeset(Map.merge(%{name: "Test event"}, Map.new(attrs)))
      |> Repo.insert()

    event
  end

  # A coherent endgame window well in the past (30-min shrink, 1-hour lead
  # from the start) — its shape is what the +/- clock shifts preserve.
  defp insert_endgame_event do
    insert_event(
      start_time: ~U[2020-01-01 00:00:00Z],
      endgame_starts_at: ~U[2020-01-01 01:00:00Z],
      endgame_ends_at: ~U[2020-01-01 01:30:00Z],
      endgame_latitude: 51.0,
      endgame_longitude: -114.0,
      endgame_initial_radius_m: 800.0,
      endgame_final_radius_m: 50.0
    )
  end

  test "playable validates draft/in_review puzzlets", %{author: author} do
    draft = insert(:puzzlet, creator_id: author.id, status: :draft)
    review = insert(:puzzlet, creator_id: author.id, status: :in_review)

    assert %{validated: validated} = Seed.playable()
    assert validated >= 2
    assert Repo.get(Puzzlet, draft.id).status == :validated
    assert Repo.get(Puzzlet, review.id).status == :validated
  end

  test "teams builds a team for every teamless user", %{players: players} do
    assert %{built: built} = Seed.teams()
    assert built >= length(players)

    for p <- players do
      assert Repo.get(User, p.id).team_id != nil
    end
  end

  test "captures plays real gameplay and records captures", %{poles: poles} do
    Seed.teams()

    assert %{captured: captured, flips: _, in_progress: _} = Seed.captures(length(poles))
    assert captured > 0
    # Every capture is a real Capture row from the scan→answer flow.
    assert Repo.aggregate(OwnershipEvent, :count) >= captured
  end

  test "captures raises when no team can play (only the author has a team)", %{author: author} do
    # Drop everyone but the author, and put the author on a team. The author
    # can't answer its own content, so no team can play.
    Repo.delete_all(from(u in User, where: u.id != ^author.id))
    author |> Ecto.Changeset.change(team_id: insert(:team).id) |> Repo.update!()

    assert_raise RuntimeError, ~r/non-author member/, fn -> Seed.captures(3) end
  end

  test "capture_all captures every capturable pole", %{poles: poles} do
    Seed.teams()

    assert %{captured: captured, uncapturable: uncapturable} = Seed.capture_all()
    assert captured == length(poles)
    # uncapturable counts poles left without an owner — a fully conquered map is 0.
    assert uncapturable == 0
  end

  test "capture_all reports poles it can't take (no player-facing puzzlet)", %{author: author} do
    Seed.teams()

    # An extra pole whose only puzzlet is validator-only — never capturable.
    lonely = insert(:pole, creator_id: author.id)
    insert(:puzzlet, pole: lonely, creator_id: author.id, status: :validated, validator_only: true)

    assert %{uncapturable: uncapturable} = Seed.capture_all()
    assert uncapturable >= 1
  end

  test "liberate frees the requested share of owned zones via the real flow" do
    Seed.teams()
    Seed.capture_all()

    owned_before = owned_zone_count()
    assert owned_before > 0

    assert %{liberated: liberated, owned: owned, requested: requested} = Seed.liberate(50)
    assert owned == owned_before
    assert requested == round(owned_before * 50 / 100)
    assert liberated == requested
    # The freed zones are gone from the owned set (their newest event is a
    # liberation, so the domain no longer reads them as owned).
    assert owned_zone_count() == owned_before - liberated
    assert Repo.aggregate(from(c in OwnershipEvent, where: c.kind == "liberate"), :count) == liberated
  end

  test "liberate flags an active endgame that refuses out-of-radius poles" do
    Seed.teams()
    Seed.capture_all()
    owned_before = owned_zone_count()
    assert owned_before > 0

    # Configure an endgame shrink that's active NOW, centred far from the
    # fixture poles (51.04,-114.07) with a tiny radius — so every owned pole
    # is outside it. Update the CURRENT event rather than inserting a second:
    # capture_all's scan path already lazily created a placeholder event via
    # Events.current/0, and a same-second insert would tie it on inserted_at.
    from(e in Event, order_by: [desc: e.inserted_at], limit: 1)
    |> Repo.one()
    |> Ecto.Changeset.change(%{
      start_time: DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second),
      endgame_starts_at: DateTime.utc_now() |> DateTime.add(-600, :second) |> DateTime.truncate(:second),
      endgame_ends_at: DateTime.utc_now() |> DateTime.add(600, :second) |> DateTime.truncate(:second),
      endgame_latitude: 40.0,
      endgame_longitude: -80.0,
      endgame_initial_radius_m: 50.0,
      endgame_final_radius_m: 10.0
    })
    |> Repo.update!()

    assert %{liberated: 0, requested: requested, endgame_active: true} = Seed.liberate(90)
    assert requested > 0
    # Nothing freed — the zones are all still owned.
    assert owned_zone_count() == owned_before
  end

  test "liberate raises without two playing teams", %{author: author, players: players} do
    # Leave only the author and a single non-author, so there's exactly one
    # playing team. Done before any captures so no attempts reference the
    # users being removed.
    keep = hd(players)
    Repo.delete_all(from(u in User, where: u.id not in ^[author.id, keep.id]))
    Seed.teams()

    assert_raise RuntimeError, ~r/two playing teams/, fn -> Seed.liberate(50) end
  end

  test "subvert_all invites and accepts every member team, with real notifications" do
    Seed.teams()
    member_team_ids = member_team_ids()
    assert length(member_team_ids) > 0

    assert %{teams: teams, invited: invited, accepted: accepted} = Seed.subvert_all()
    assert teams == length(member_team_ids)
    assert invited == teams
    assert accepted == teams

    # Every member team is now a liberator, with a real (answered) invite.
    for id <- member_team_ids do
      t = Repo.get(Team, id)
      assert t.liberation_response == "accepted"
      assert t.liberation_invited_at
      assert Landgrab.liberator?(id)

      assert Repo.aggregate(
               from(n in Notification,
                 where: n.recipient_team_id == ^id and n.type == "liberation_invite"
               ),
               :count
             ) == 1
    end
  end

  test "subvert_all is idempotent — a second run re-invites/accepts nobody" do
    Seed.teams()
    Seed.subvert_all()

    assert %{invited: 0, accepted: 0} = Seed.subvert_all()
  end

  test "subvert_team invites and accepts one named team, case-insensitively", %{players: players} do
    Seed.teams()
    # Give one player a distinct team name to target unambiguously.
    target = Repo.get(User, hd(players).id).team_id
    Team |> Repo.get(target) |> Ecto.Changeset.change(name: "Correct Horse") |> Repo.update!()

    assert %{team: "Correct Horse", invited: true, accepted: true} =
             Seed.subvert_team("correct horse")

    assert Landgrab.liberator?(target)
    # Other member teams are untouched.
    others = Enum.reject(member_team_ids(), &(&1 == target))
    for id <- others, do: refute(Landgrab.liberator?(id))
  end

  test "subvert_team raises on an unknown name" do
    Seed.teams()
    assert_raise RuntimeError, ~r/no team named/, fn -> Seed.subvert_team("nobody here") end
  end

  defp member_team_ids do
    Repo.all(from(t in Team, join: u in User, on: u.team_id == t.id, distinct: true, select: t.id))
  end

  defp owned_zone_count do
    Enum.count(Landgrab.list_poles_with_state(), &(&1.current_owner_team_id != nil))
  end

  test "validations fills the test validator's queue with assigned work",
       %{validator: validator} do
    assert %{assigned: assigned, validator: email} = Seed.validations(2)
    assert email == Seed.validator_email()
    assert assigned == 2

    open =
      Repo.all(
        from(v in PuzzletValidation,
          where: v.validator_id == ^validator.id and v.status == "assigned",
          select: v.puzzlet_id
        )
      )

    assert length(open) == 2
    # Assigning an already-validated puzzlet leaves it validated (in play) —
    # only a *draft* is flipped to :in_review on assignment.
    for id <- open, do: assert(Repo.get(Puzzlet, id).status == :validated)
  end

  test "clear wipes captures, in-progress claims, and gameplay notifications" do
    Seed.teams()
    Seed.captures(6)

    assert %{captures: _, in_progress: _, notifications: _} = Seed.clear()
    assert Repo.aggregate(OwnershipEvent, :count) == 0
    assert Repo.aggregate(TeamPuzzlet, :count) == 0
  end

  test "clear wipes answer attempts, so a locked-out team isn't re-locked on the fresh map" do
    team = insert(:team)
    user = insert(:user, team_id: team.id)
    puzzlet = insert(:puzzlet, pole: insert(:pole))

    for given <- ["a", "b", "c"] do
      insert(:attempt, puzzlet: puzzlet, team: team, user: user, correct: false, answer_given: given)
    end

    # Three wrong guesses = locked out (all-time count, no window).
    assert Landgrab.team_locked_out?(Repo.get(Puzzlet, puzzlet.id), team.id)

    assert %{wrong_answers: 3} = Seed.clear()

    assert Repo.aggregate(Attempt, :count) == 0
    refute Landgrab.team_locked_out?(Repo.get(Puzzlet, puzzlet.id), team.id)
  end

  test "clear resets the liberation rollout: invites, answers, and schedule" do
    Seed.teams()

    # Run a real rollout to completion: schedule in the past, every team due.
    insert_event(liberation_starts_at: ~U[2020-01-01 00:00:00Z])
    {:invited, invited} = Landgrab.maybe_invite_liberation_teams()
    assert invited > 0

    assert %{liberation_teams: ^invited} = Seed.clear()

    assert Repo.aggregate(from(t in Team, where: not is_nil(t.liberation_invited_at)), :count) == 0
    assert Repo.aggregate(from(n in Notification, where: n.type == "liberation_invite"), :count) == 0
    # The schedule is gone too, so the announcer won't immediately re-invite.
    assert Repo.aggregate(from(e in Event, where: not is_nil(e.liberation_starts_at)), :count) == 0
  end

  test "clear closes the relief valve" do
    insert_event(relief_started_at: ~U[2020-01-01 00:00:00Z])
    assert Landgrab.relief_active?()

    Seed.clear()

    refute Landgrab.relief_active?()
    assert Repo.aggregate(from(e in Event, where: not is_nil(e.relief_started_at)), :count) == 0
  end

  test "abort clears every notification type and organiser messages, not just clear's three" do
    Seed.teams()

    # An organiser broadcast fans out into per-team `message` notifications —
    # neither of which `clear` touches, but `abort` must.
    {:ok, message} = Landgrab.create_organiser_message(%{body: "Onward", sender_name: "SYSTEM"})
    {:ok, _sent, count} = Landgrab.send_organiser_message(message)
    assert count > 0

    result = Seed.abort()
    assert result.notifications >= count
    assert result.organiser_messages == 1
    assert Repo.aggregate(Notification, :count) == 0
    assert Repo.aggregate(OrganiserMessage, :count) == 0
  end

  test "abort disarms the endgame timeline so the announcers go inert" do
    insert_endgame_event()

    assert %{events: 1} = Seed.abort()

    e = Repo.one(Event)
    assert is_nil(e.start_time)
    assert is_nil(e.endgame_starts_at)
    assert is_nil(e.endgame_ends_at)
    assert is_nil(e.endgame_announced_at)
    assert is_nil(e.final_messages_sent_at)
    assert is_nil(e.relief_started_at)
    # Nothing to announce or freeze once the timeline is blank.
    assert Landgrab.maybe_announce_endgame() == :noop
    assert Landgrab.maybe_send_final_location_messages() == :noop
  end

  test "schedule lays out the whole timeline as fixed fractions of X minutes" do
    event = insert_event(start_time: ~U[2020-01-01 00:00:00Z])

    assert %{
             events: 1,
             minutes: 30,
             endgame_start_s: 900,
             liberation_start_s: 1125,
             liberation_end_s: 1350,
             end_s: 1800
           } = Seed.schedule(30)

    e = Repo.get(Event, event.id)
    now = DateTime.utc_now()
    # start now, shrink at 15m, liberation 18.75m–22.5m, end at 30m.
    assert_in_delta DateTime.diff(e.start_time, now), 0, 5
    assert_in_delta DateTime.diff(e.endgame_starts_at, now), 900, 5
    assert_in_delta DateTime.diff(e.liberation_starts_at, now), 1125, 5
    assert_in_delta DateTime.diff(e.liberation_rollout_ends_at, now), 1350, 5
    assert_in_delta DateTime.diff(e.endgame_ends_at, now), 1800, 5
  end

  test "schedule fills a default endgame location when the event has none, and re-arms stamps" do
    event =
      insert_event(
        start_time: ~U[2020-01-01 00:00:00Z],
        endgame_announced_at: ~U[2020-01-01 00:30:00Z]
      )

    Seed.schedule(30)

    e = Repo.get(Event, event.id)
    assert e.endgame_latitude && e.endgame_longitude
    assert e.endgame_initial_radius_m && e.endgame_final_radius_m
    # One-shot stamp cleared so the compressed run re-announces.
    assert is_nil(e.endgame_announced_at)
  end

  test "schedule preserves an existing endgame location" do
    event = insert_endgame_event()

    Seed.schedule(30)

    e = Repo.get(Event, event.id)
    assert {e.endgame_latitude, e.endgame_longitude} == {51.0, -114.0}
    assert {e.endgame_initial_radius_m, e.endgame_final_radius_m} == {800.0, 50.0}
  end

  test "clock:M puts the start M minutes from now" do
    event = insert_event(start_time: ~U[2020-01-01 00:00:00Z])

    assert %{anchor: :start_time, seconds: 1800, events: 1} = Seed.clock("30")

    secs = DateTime.diff(Repo.get(Event, event.id).start_time, DateTime.utc_now())
    assert_in_delta secs, 1800, 5
  end

  test "clock shifts a set liberation window along with the timeline" do
    # Liberation set 45 min after the start with a 15-min rollout — the
    # shift must preserve both intervals.
    event =
      insert_event(
        start_time: ~U[2020-01-01 00:00:00Z],
        liberation_starts_at: ~U[2020-01-01 00:45:00Z],
        liberation_rollout_ends_at: ~U[2020-01-01 01:00:00Z]
      )

    Seed.clock("30")

    reloaded = Repo.get(Event, event.id)
    assert DateTime.diff(reloaded.liberation_starts_at, reloaded.start_time) == 45 * 60
    assert DateTime.diff(reloaded.liberation_rollout_ends_at, reloaded.liberation_starts_at) == 15 * 60
  end

  test "clock:M.SS reads the fractional part as seconds, not decimal minutes" do
    event = insert_event(start_time: ~U[2020-01-01 00:00:00Z])

    # 0.30 must be 30 seconds (not 0.3 min = 18s).
    assert %{seconds: 30} = Seed.clock("0.30")

    secs = DateTime.diff(Repo.get(Event, event.id).start_time, DateTime.utc_now())
    assert_in_delta secs, 30, 5
  end

  test "a positive clock anchors just after the endgame shrink begins (midgame)" do
    event = insert_endgame_event()

    # +2 = 2 minutes after the shrink begins; radius still near its widest.
    assert %{anchor: :endgame_starts_at, direction: :after, seconds: 120, events: 1} =
             Seed.clock("+2")

    reloaded = Repo.get(Event, event.id)
    # The shrink began 2 minutes ago, and the event is under way (start is past).
    assert_in_delta DateTime.diff(DateTime.utc_now(), reloaded.endgame_starts_at), 120, 5
    assert DateTime.before?(reloaded.start_time, DateTime.utc_now())
    # Window shape preserved: 30-min shrink, 1-hour lead from start.
    assert DateTime.diff(reloaded.endgame_ends_at, reloaded.endgame_starts_at) == 1800
    assert DateTime.diff(reloaded.endgame_starts_at, reloaded.start_time) == 3600
  end

  test "a negative clock anchors on the endgame shrink end and shifts the whole window" do
    event = insert_endgame_event()

    # -0.30 = 30 seconds before the shrink ends.
    assert %{anchor: :endgame_ends_at, direction: :before, seconds: 30, events: 1} =
             Seed.clock("-0.30")

    reloaded = Repo.get(Event, event.id)
    ends_in = DateTime.diff(reloaded.endgame_ends_at, DateTime.utc_now())
    assert_in_delta ends_in, 30, 5

    # The 30-minute shrink window and its 1-hour lead from start are preserved.
    assert DateTime.diff(reloaded.endgame_ends_at, reloaded.endgame_starts_at) == 1800
    assert DateTime.diff(reloaded.endgame_starts_at, reloaded.start_time) == 3600
  end

  test "-0 is treated as negative (the sign, not the number, picks the anchor)" do
    insert_endgame_event()
    assert %{anchor: :endgame_ends_at, seconds: 0} = Seed.clock("-0")
  end

  test "a +/- clock without an endgame window raises" do
    insert_event(start_time: ~U[2020-01-01 00:00:00Z])
    assert_raise RuntimeError, ~r/endgame window/, fn -> Seed.clock("-1") end
    assert_raise RuntimeError, ~r/endgame window/, fn -> Seed.clock("+2") end
  end

  test "filler creates teamless users that names/teams can pick up" do
    assert %{created: created} = Seed.filler(3)
    assert created == 3

    fillers = Repo.all(from(u in User, where: like(u.email, "filler+%"), select: u))
    assert length(fillers) == 3
    assert Enum.all?(fillers, &(&1.team_id == nil))
    assert Enum.all?(fillers, &(&1.proposed_team_name != nil))
  end
end
