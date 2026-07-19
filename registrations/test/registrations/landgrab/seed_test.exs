defmodule Registrations.Landgrab.SeedTest do
  @moduledoc """
  Smoke test for the scenario seeder. It doesn't assert exact fixtures —
  it asserts that each step still runs end-to-end through the real domain
  and produces the shape of state it promises. If a schema change or a
  gameplay/validation refactor breaks seeding, this fails here instead of
  mid-event. It also documents what each step is supposed to produce.
  """
  use Registrations.DataCase

  alias Registrations.Landgrab.Capture
  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.Seed
  alias Registrations.Landgrab.TeamPuzzlet
  alias Registrations.Landgrab.Validations.PuzzletValidation
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
    assert Repo.aggregate(Capture, :count) >= captured
  end

  test "captures raises when no team can play (only the author has a team)", %{author: author} do
    # Drop everyone but the author, and put the author on a team. The author
    # can't answer its own content, so no team can play.
    Repo.delete_all(from(u in User, where: u.id != ^author.id))
    author |> Ecto.Changeset.change(team_id: insert(:team).id) |> Repo.update!()

    assert_raise RuntimeError, ~r/non-author member/, fn -> Seed.captures(3) end
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
    assert Repo.aggregate(Capture, :count) == 0
    assert Repo.aggregate(TeamPuzzlet, :count) == 0
  end

  test "clock:M puts the start M minutes from now" do
    event = insert_event(start_time: ~U[2020-01-01 00:00:00Z])

    assert %{anchor: :start_time, seconds: 1800, events: 1} = Seed.clock("30")

    secs = DateTime.diff(Repo.get(Event, event.id).start_time, DateTime.utc_now())
    assert_in_delta secs, 1800, 5
  end

  test "clock:M.SS reads the fractional part as seconds, not decimal minutes" do
    event = insert_event(start_time: ~U[2020-01-01 00:00:00Z])

    # 0.30 must be 30 seconds (not 0.3 min = 18s).
    assert %{seconds: 30} = Seed.clock("0.30")

    secs = DateTime.diff(Repo.get(Event, event.id).start_time, DateTime.utc_now())
    assert_in_delta secs, 30, 5
  end

  test "a negative clock anchors on the endgame shrink end and shifts the whole window" do
    # A coherent endgame window well in the past, its shape to be preserved.
    event =
      insert_event(
        start_time: ~U[2020-01-01 00:00:00Z],
        endgame_starts_at: ~U[2020-01-01 01:00:00Z],
        endgame_ends_at: ~U[2020-01-01 01:30:00Z],
        endgame_latitude: 51.0,
        endgame_longitude: -114.0,
        endgame_initial_radius_m: 800.0,
        endgame_final_radius_m: 50.0
      )

    # -0.30 = 30 seconds before the shrink ends.
    assert %{anchor: :endgame_ends_at, seconds: 30, events: 1} = Seed.clock("-0.30")

    reloaded = Repo.get(Event, event.id)
    ends_in = DateTime.diff(reloaded.endgame_ends_at, DateTime.utc_now())
    assert_in_delta ends_in, 30, 5

    # The 30-minute shrink window and its 1-hour lead from start are preserved.
    assert DateTime.diff(reloaded.endgame_ends_at, reloaded.endgame_starts_at) == 1800
    assert DateTime.diff(reloaded.endgame_starts_at, reloaded.start_time) == 3600
  end

  test "-0 is treated as negative (the sign, not the number, picks the anchor)" do
    insert_event(
      start_time: ~U[2020-01-01 00:00:00Z],
      endgame_starts_at: ~U[2020-01-01 01:00:00Z],
      endgame_ends_at: ~U[2020-01-01 01:30:00Z],
      endgame_latitude: 51.0,
      endgame_longitude: -114.0,
      endgame_initial_radius_m: 800.0,
      endgame_final_radius_m: 50.0
    )

    assert %{anchor: :endgame_ends_at, seconds: 0} = Seed.clock("-0")
  end

  test "a negative clock without an endgame window raises" do
    insert_event(start_time: ~U[2020-01-01 00:00:00Z])
    assert_raise RuntimeError, ~r/endgame window/, fn -> Seed.clock("-1") end
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
