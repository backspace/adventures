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

  test "clock moves the event start_time into the future" do
    {:ok, event} =
      %Event{}
      |> Event.changeset(%{name: "Test event", start_time: ~U[2020-01-01 00:00:00Z]})
      |> Repo.insert()

    assert %{minutes: 30, events: 1} = Seed.clock(30)

    updated = Repo.get(Event, event.id)
    assert DateTime.compare(updated.start_time, DateTime.utc_now()) == :gt
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
