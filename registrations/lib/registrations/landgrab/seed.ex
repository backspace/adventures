defmodule Registrations.Landgrab.Seed do
  @moduledoc """
  Composable scenario seeding for the LANDGRAB local/test database.

  Every step runs through the real domain — the gameplay flow
  (`scan_payload` → `record_attempt`), the team builder, and the
  validation context — rather than raw SQL that can silently drift from
  the schema. Ecto's compile-time field checks catch renamed/removed
  columns, and `Registrations.Landgrab.SeedTest` exercises these
  functions so behaviour drift fails a test rather than surprising you
  mid-event.

  `Mix.Tasks.Landgrab.Seed` is the thin CLI over these functions; each
  returns a small result map the task formats for the console. Nothing
  here guards against a production database — that safety lives in the
  Mix task, since these functions run against whatever the Repo points
  at (in tests, the sandbox).
  """
  import Ecto.Query

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Notification
  alias Registrations.Landgrab.OrganiserMessage
  alias Registrations.Landgrab.OwnershipEvent
  alias Registrations.Landgrab.Pole
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.TeamPuzzlet
  alias Registrations.Landgrab.Validations
  alias Registrations.Landgrab.Validations.PuzzletValidation
  alias Registrations.Repo
  alias RegistrationsWeb.Team
  alias RegistrationsWeb.TeamBuilder
  alias RegistrationsWeb.User

  @validator_email "buck.doyle+validator@gmail.com"
  @assigner_email "b@chromatin.ca"

  # Word banks for memorable two-word team names ("correct horse" style).
  @adjectives ~w(correct brave quiet sly amber velvet crimson lucky mellow rustic
                 cosmic feral gentle jolly nimble plucky rugged spry vivid witty)
  @nouns ~w(horse battery otter river staple ember pixel comet meadow lantern
            walrus thistle harbor badger cinder marble sparrow tundra cactus falcon)

  @doc "The email of the test validator the `validations` step assigns to."
  def validator_email, do: @validator_email

  # ── playable ────────────────────────────────────────────────────────
  @doc """
  Validate every draft/in_review puzzlet and attach the loose
  (non-validator-only) ones to their nearest pole. Returns
  `%{validated: n, attached: m}`.
  """
  def playable do
    {validated, _} =
      Repo.update_all(
        from(z in Puzzlet, where: z.status in [:draft, :in_review]),
        set: [status: :validated, updated_at: now()]
      )

    %{validated: validated, attached: attach_loose_puzzlets()}
  end

  defp attach_loose_puzzlets do
    pole_ids = Repo.all(from(p in Pole, select: p.id))

    located_poles =
      Repo.all(
        from(p in Pole,
          where: not is_nil(p.latitude) and not is_nil(p.longitude),
          select: %{id: p.id, lat: p.latitude, lng: p.longitude}
        )
      )

    from(z in Puzzlet,
      where: is_nil(z.pole_id) and not z.validator_only,
      select: %{id: z.id, lat: z.latitude, lng: z.longitude}
    )
    |> Repo.all()
    |> Enum.reduce(0, fn z, acc ->
      target =
        cond do
          z.lat && z.lng && located_poles != [] ->
            Enum.min_by(located_poles, fn p -> sq(p.lat - z.lat) + sq(p.lng - z.lng) end).id

          pole_ids != [] ->
            # Locationless: spread deterministically rather than piling on one.
            Enum.at(pole_ids, rem(:erlang.phash2(z.id), length(pole_ids)))

          true ->
            nil
        end

      if target do
        Repo.update_all(from(p in Puzzlet, where: p.id == ^z.id),
          set: [pole_id: target, updated_at: now()]
        )

        acc + 1
      else
        acc
      end
    end)
  end

  # ── teams ───────────────────────────────────────────────────────────
  @doc """
  Build teams for every teamless user through the real `TeamBuilder`.
  Returns `%{built: n}`.
  """
  def teams, do: %{built: sweep_teams(0)}

  defp sweep_teams(built) do
    case Repo.one(from(u in User, where: is_nil(u.team_id), order_by: u.inserted_at, limit: 1)) do
      nil ->
        built

      user ->
        case TeamBuilder.build_for(user) do
          {:ok, _team, _fallbacks} -> sweep_teams(built + 1)
          {:error, changeset} -> raise "team build failed for #{user.email}: #{inspect(changeset.errors)}"
        end
    end
  end

  # ── filler users / team names ───────────────────────────────────────
  @doc """
  Create N teamless filler users, each with a memorable proposed team
  name so a following `teams` step builds a nicely-named solo team from
  it. Idempotent by email. Returns `%{created: n}`.
  """
  def filler(n) do
    names = two_word_names(n, team_and_proposed_names())

    created =
      Enum.reduce(names, 0, fn name, acc ->
        email = "filler+" <> String.replace(name, " ", "-") <> "@example.test"

        if Repo.get_by(User, email: email) do
          acc
        else
          {:ok, _} =
            %User{}
            |> Ecto.Changeset.change(%{email: email, proposed_team_name: name})
            |> Repo.insert()

          acc + 1
        end
      end)

    %{created: created}
  end

  @doc """
  Rename the team-builder's "FIXME" placeholder teams (loners who gave no
  proposed name) to memorable two-word names. Returns `%{renamed: n}`.
  """
  def names do
    fixme = Repo.all(from(t in Team, where: t.name == "FIXME", select: t.id))

    fixme
    |> Enum.zip(two_word_names(length(fixme), existing_team_names()))
    |> Enum.each(fn {id, name} ->
      Repo.update_all(from(t in Team, where: t.id == ^id), set: [name: name])
    end)

    %{renamed: length(fixme)}
  end

  # ── validations ─────────────────────────────────────────────────────
  @doc """
  Assign up to N validated, uncaptured puzzlets to the test validator
  through the validation context, filling their to-do queue. Each gets an
  `assigned` PuzzletValidation; the puzzlet itself stays `:validated`
  (assignment only flips a *draft* into `:in_review`). Idempotent — skips
  puzzlets already open for that validator. Returns
  `%{assigned: n, validator: email}`.
  """
  def validations(n) do
    validator = user!(@validator_email, "validator")
    assigner = user!(@assigner_email, "assigner")

    open =
      from(v in PuzzletValidation,
        where: v.validator_id == ^validator.id and v.status not in ["accepted", "rejected"],
        select: v.puzzlet_id
      )

    captured = from(c in OwnershipEvent, where: not is_nil(c.puzzlet_id), select: c.puzzlet_id)

    assigned =
      from(z in Puzzlet,
        where: z.status == :validated and not z.validator_only,
        where: z.id not in subquery(captured),
        where: z.id not in subquery(open),
        select: z.id,
        limit: ^n
      )
      |> Repo.all()
      |> Enum.reduce(0, fn puzzlet_id, acc ->
        case Validations.assign_puzzlet_validation(puzzlet_id, validator.id, assigner.id) do
          {:ok, _} -> acc + 1
          _ -> acc
        end
      end)

    %{assigned: assigned, validator: validator.email}
  end

  # ── captures (partial gameplay, driven through the REAL game) ───────
  # Rather than inserting Capture/Notification rows by hand, this plays the
  # actual scan → answer flow (`scan_payload` then `record_attempt`), so
  # every capture, attack, pole-loss, pole-contested signal, in-progress
  # claim, and broadcast is produced by the real game with its real copy.
  # Slower, but true to real-world conditions.
  @doc """
  Partial gameplay: capture up to N poles spread across the teams, with a
  few active attacks and in-progress claims — all through the real
  scan → answer flow. Raises if no team has a non-author member (the
  content author can't answer its own puzzlets). Returns
  `%{captured: n, flips: n, in_progress: n}`.
  """
  def captures(n) do
    players = player_teams()

    if players == [] do
      raise "captures needs a team with a non-author member — run teams/filler first. " <>
              "(The content author's own team can't answer its own puzzlets.)"
    end

    owned = play_first_wave(unowned_capturable_poles(n), players)
    flips = play_flips(owned, players)
    in_progress = play_in_progress(players)

    %{captured: length(owned), flips: flips, in_progress: in_progress}
  end

  @doc """
  Capture EVERY capturable pole, round-robin across the player teams, through
  the real scan → answer flow — a fully-owned map, with no contested/in-progress
  noise. A pole is capturable when it has a validated, player-facing puzzlet a
  non-author team can answer; a pole without one can't be taken this way and
  stays unowned (reported as `uncapturable` — run `playable` first to validate
  and attach puzzlets so this is 0). Needs the endgame inactive — an active
  shrink refuses out-of-radius poles — so run it pre-event. Raises if no team
  has a non-author member. Returns `%{captured: n, uncapturable: n}`.
  """
  def capture_all do
    players = player_teams()

    if players == [] do
      raise "capture_all needs a team with a non-author member — run teams/filler first. " <>
              "(The content author's own team can't answer its own puzzlets.)"
    end

    captured = length(play_first_wave(all_capturable_poles(), players))
    %{captured: captured, uncapturable: unowned_pole_count()}
  end

  # Poles with no owner. After capture_all, these are the uncapturable ones
  # (no validated, player-facing puzzlet to answer).
  defp unowned_pole_count do
    Repo.aggregate(from(p in Pole, where: p.id not in subquery(owned_pole_ids_query())), :count)
  end

  # ── liberate (free a share of owned zones, through the REAL game) ────
  @doc """
  Free `percent`% of the currently-owned zones through the real liberation
  flow: a liberator team (one that ACCEPTED Bedab's invitation) scans an
  owned pole and answers its relic, which *frees* the stake instead of
  taking it — a newest-wins `liberate` ownership event, so the pole then
  reads as liberated. The playing teams are accepted into liberation so they
  can do the freeing, and each target zone is freed by a team that ISN'T its
  current owner (a team can't re-solve the relic it already captured). Needs
  the endgame inactive (an active shrink refuses out-of-radius poles) and a
  not-yet-ended game — so run it pre-event or mid-arc. Raises without at
  least two playing teams (nobody to free another team's ground). Percent is
  of the zones owned *now*, so re-running frees a share of what's left.
  Returns `%{liberated: n, owned: total_owned, requested: n, endgame_active:
  bool}` — `endgame_active` flags the common reason a run frees fewer than
  requested (an active shrink refuses out-of-radius poles).
  """
  def liberate(percent) when is_integer(percent) and percent >= 0 and percent <= 100 do
    players = player_teams()

    if length(players) < 2 do
      raise "liberate needs at least two playing teams — one frees another's ground. " <>
              "Run teams/filler first."
    end

    accept_liberation(players)
    age_captures()

    owned = owned_zones()
    requested = round(length(owned) * percent / 100)

    liberated =
      owned
      |> Enum.take(requested)
      |> Enum.reduce(0, fn zone, acc ->
        freer = Enum.find(players, &(&1.team_id != zone.owner_team_id))
        if freer && play_liberate(zone, freer), do: acc + 1, else: acc
      end)

    # If the shrink is active, poles outside its radius are refused — the
    # usual reason a run frees fewer than requested (or zero). Surface it so
    # the caller can explain the shortfall instead of a silent "freed 0".
    %{liberated: liberated, owned: length(owned), requested: requested, endgame_active: endgame_active?()}
  end

  defp endgame_active? do
    now = now()

    Event
    |> Repo.all()
    |> Enum.any?(&(Event.endgame_zone(&1, now) != nil))
  end

  # A liberation only registers if it's the NEWEST event for its pole, but
  # ownership is derived by ordering on second-precision `inserted_at` with
  # no tiebreak — so a capture and liberation in the same wall-clock second
  # tie, and the capture wins. Nudge existing captures an hour into the past
  # (a constant shift, so their relative order is preserved) so a just-now
  # liberation reliably wins even in a single `capture_all liberate` command.
  # Captures precede liberations anyway, so this only makes the log honest.
  defp age_captures do
    Repo.update_all(
      from(c in OwnershipEvent,
        where: c.kind == "capture",
        update: [set: [inserted_at: fragment("? - interval '1 hour'", c.inserted_at)]]
      ),
      []
    )
  end

  # Mark the playing teams as liberation-accepters, so their scan→answer
  # frees rather than takes. Idempotent (players are unique by team).
  defp accept_liberation(players) do
    stamp = now()

    Enum.each(players, fn %{team_id: team_id} ->
      Team
      |> Repo.get(team_id)
      |> Ecto.Changeset.change(%{
        liberation_response: "accepted",
        liberation_invited_at: stamp,
        liberation_responded_at: stamp
      })
      |> Repo.update!()
    end)
  end

  # Currently-owned zones (newest event a capture), with owner + barcode —
  # the domain derives ownership, so already-liberated poles drop out.
  defp owned_zones do
    Landgrab.list_poles_with_state()
    |> Enum.filter(&(&1.current_owner_team_id != nil))
    |> Enum.map(fn %{pole: pole, current_owner_team_id: owner} ->
      %{barcode: pole.barcode, owner_team_id: owner}
    end)
  end

  # One real scan → answer as a liberator on an owned pole. True when the
  # answer freed it; frees the claimed slot again on any other outcome so
  # capacity stays clear for the next zone.
  defp play_liberate(zone, freer) do
    case Landgrab.scan_payload(zone.barcode, freer.team_id, freer.user_id) do
      {:ok, %{active_puzzlet: %Puzzlet{id: id}}} ->
        puzzlet = Repo.get(Puzzlet, id)

        case Landgrab.record_attempt(puzzlet, freer.team_id, freer.user_id, puzzlet.answer) do
          {:ok, %{result: :liberated}} ->
            true

          _ ->
            Landgrab.abandon_active_puzzlet(freer.team_id, id)
            false
        end

      _ ->
        false
    end
  end

  # ── subversion (liberation) invitation state ────────────────────────
  # "Subversion" is the player-facing name for the liberation phase (Bedab's
  # "Join me?" invite). These seed the invitation *state* — the invite has
  # gone out and been accepted — through the real invite + respond flow (real
  # notifications, real stance), without freeing any zones (that's `liberate`).

  @doc """
  Invite EVERY team with members into the subversion and accept for all of
  them — the state where the invitation has gone out and every team joined.
  Marks the liberation phase begun if it wasn't. Idempotent. Returns
  `%{teams: n, invited: n, accepted: n}` (invited/accepted count only the
  ones this run newly invited/accepted).
  """
  def subvert_all do
    invite_and_respond_all("accepted")
  end

  @doc """
  Invite a single team BY NAME into the subversion and accept for it. The
  name is matched case-insensitively (trimmed); raises if none matches.
  Marks the liberation phase begun if it wasn't. Returns
  `%{team: name, invited: bool, accepted: bool}`.
  """
  def subvert_team(name) when is_binary(name) do
    invite_and_respond_team(name, "accepted")
  end

  @doc """
  Invite EVERY team with members into the subversion and DECLINE for all of
  them — the state where the invitation went out and every team turned it
  down. Marks the liberation phase begun if it wasn't. Idempotent. Returns
  `%{teams: n, invited: n, declined: n}` (invited/declined count only the
  ones this run newly invited/answered).
  """
  def unsubvert_all do
    invite_and_respond_all("declined")
  end

  @doc """
  Invite a single team BY NAME into the subversion and DECLINE for it. The
  name is matched case-insensitively (trimmed); raises if none matches.
  Marks the liberation phase begun if it wasn't. Returns
  `%{team: name, invited: bool, declined: bool}`.
  """
  def unsubvert_team(name) when is_binary(name) do
    invite_and_respond_team(name, "declined")
  end

  # The response key mirrors the verb: "accepted" reports :accepted,
  # "declined" reports :declined — so subvert_* and unsubvert_* return maps
  # that read naturally in the task's console summary.
  defp invite_and_respond_all(response) do
    ensure_liberation_begun()
    results = Enum.map(member_teams(), &subvert(&1, response))

    Map.put(
      %{teams: length(results), invited: Enum.count(results, & &1.invited)},
      response_key(response),
      Enum.count(results, & &1.responded)
    )
  end

  defp invite_and_respond_team(name, response) do
    team = find_team_by_name!(name)
    ensure_liberation_begun()
    r = subvert(team, response)

    Map.put(%{team: team.name, invited: r.invited}, response_key(response), r.responded)
  end

  defp response_key("accepted"), do: :accepted
  defp response_key("declined"), do: :declined

  # Invite (real notification) then answer (real respond) one team with the
  # given response. Both steps are idempotent — an already-invited or
  # already-answered team just reports false for that step.
  defp subvert(%Team{} = team, response) do
    invited =
      case Landgrab.invite_liberation_team(team) do
        {:ok, _} -> true
        {:already_invited, _} -> false
      end

    %{invited: invited, responded: respond_liberation_invite(team.id, response)}
  end

  # Answer the team's outstanding liberation invite through the real respond
  # flow. False when there's no open invite (missing or already answered).
  defp respond_liberation_invite(team_id, response) do
    invite =
      Repo.one(
        from(n in Notification,
          where:
            n.recipient_team_id == ^team_id and n.type == "liberation_invite" and
              is_nil(n.response),
          order_by: [desc: n.inserted_at],
          limit: 1
        )
      )

    match?(
      {:ok, _},
      invite && Landgrab.respond_to_liberation_invite(team_id, invite.id, response)
    )
  end

  defp find_team_by_name!(name) do
    trimmed = String.trim(name)
    needle = String.downcase(trimmed)

    case Repo.all(from(t in Team, where: fragment("lower(?)", t.name) == ^needle)) do
      [team] ->
        team

      [] ->
        raise "no team named #{inspect(trimmed)} — check the name (matched case-insensitively)."

      teams ->
        raise "#{length(teams)} teams are named #{inspect(trimmed)} — rename so the target is unique."
    end
  end

  # Every team with at least one member (empty QR teams aren't in the game),
  # mirroring the domain's own `member_teams` for the invite sweep.
  defp member_teams do
    Repo.all(from(t in Team, join: u in User, on: u.team_id == t.id, distinct: true, select: t))
  end

  # Mark the liberation phase begun (starts_at set) if it isn't, so seeded
  # invitations are coherent. Leaves an existing schedule untouched.
  defp ensure_liberation_begun do
    Repo.update_all(
      from(e in Event, where: is_nil(e.liberation_starts_at)),
      set: [liberation_starts_at: now()]
    )
  end

  # Teams that can actually play: one with a member who didn't author the
  # content (record_attempt rejects a puzzlet's or pole's creator).
  defp player_teams do
    authors =
      MapSet.new(
        Repo.all(from(z in Puzzlet, select: z.creator_id)) ++
          Repo.all(from(p in Pole, select: p.creator_id))
      )

    from(t in Team, join: u in User, on: u.team_id == t.id, select: %{team_id: t.id, name: t.name, user_id: u.id})
    |> Repo.all()
    |> Enum.reject(&MapSet.member?(authors, &1.user_id))
    |> Enum.uniq_by(& &1.team_id)
  end

  # First wave: round-robin players capturing still-unowned poles.
  defp play_first_wave(poles, players) do
    poles
    |> Enum.with_index()
    |> Enum.reduce([], fn {pole, i}, acc ->
      player = Enum.at(players, rem(i, length(players)))
      if play_capture(pole, player), do: [Map.put(pole, :player, player) | acc], else: acc
    end)
  end

  # Contest wave: a different player scans an owned pole (→ real attack) and
  # answers a spare puzzlet on it (→ real pole-loss + flip). Only fires on
  # poles that still have an uncaptured puzzlet.
  defp play_flips(_owned, players) when length(players) < 2, do: 0

  defp play_flips(owned, players) do
    owned
    |> Enum.uniq_by(& &1.player.team_id)
    |> Enum.reduce(0, fn o, acc ->
      attacker = Enum.find(players, &(&1.team_id != o.player.team_id))
      if attacker && play_capture(o, attacker), do: acc + 1, else: acc
    end)
  end

  # Leave a few players mid-puzzlet — a real scan on a still-unowned pole
  # that claims the puzzlet but never answers it.
  defp play_in_progress(players) do
    players
    |> length()
    |> unowned_capturable_poles()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {pole, i}, acc ->
      player = Enum.at(players, rem(i, length(players)))

      case Landgrab.scan_payload(pole.barcode, player.team_id, player.user_id) do
        {:ok, %{active_puzzlet: %Puzzlet{}}} -> acc + 1
        _ -> acc
      end
    end)
  end

  # One real scan → answer. Returns true on a capture; frees the claimed
  # slot again if the answer path didn't capture, so capacity stays clear.
  defp play_capture(pole, player) do
    case Landgrab.scan_payload(pole.barcode, player.team_id, player.user_id) do
      {:ok, %{active_puzzlet: %Puzzlet{id: id}}} ->
        puzzlet = Repo.get(Puzzlet, id)

        case Landgrab.record_attempt(puzzlet, player.team_id, player.user_id, puzzlet.answer) do
          {:ok, %{result: :captured}} ->
            true

          _ ->
            Landgrab.abandon_active_puzzlet(player.team_id, id)
            false
        end

      _ ->
        false
    end
  end

  # Unowned poles that still have an uncaptured, validated, player-facing
  # puzzlet — the ones a first-wave scan can capture. Capped variant for
  # partial gameplay; `all_capturable_poles` takes the lot for capture_all.
  defp unowned_capturable_poles(n), do: capturable_poles_query() |> Repo.all() |> Enum.take(n)

  defp all_capturable_poles, do: Repo.all(capturable_poles_query())

  defp capturable_poles_query do
    from(p in Pole,
      join: z in Puzzlet,
      on: z.pole_id == p.id,
      where: z.status == :validated and not z.validator_only,
      where: z.id not in subquery(from(c in OwnershipEvent, where: not is_nil(c.puzzlet_id), select: c.puzzlet_id)),
      where: p.id not in subquery(owned_pole_ids_query()),
      distinct: p.id,
      select: %{pole_id: p.id, barcode: p.barcode}
    )
  end

  # Pole ids that currently have an owner (any capture on one of their puzzlets).
  defp owned_pole_ids_query do
    from(c in OwnershipEvent, join: z in Puzzlet, on: z.id == c.puzzlet_id, select: z.pole_id)
  end

  # ── clock ───────────────────────────────────────────────────────────
  # Every event carries these instants; a shift moves the whole timeline
  # by one delta so the intervals between them are preserved. The
  # liberation window rides along when set, so a scripted rollout keeps
  # its place in a replayed event.
  @time_fields ~w(start_time endgame_starts_at endgame_ends_at endgame_announced_at
                  liberation_starts_at liberation_rollout_ends_at)a

  @doc """
  Position "now" relative to an event milestone by shifting the whole
  timeline (so the intervals between the milestones are preserved). The
  spec is `[±]M[.SS]` minutes — `.SS` is *seconds*, so `0.30` is 30
  seconds, not 0.3 minutes. The sign picks which of the three dramatic
  moments to sit near:

    * **`M`** (no sign) — M before the **start**. `clock("0.30")` puts the
      start 30 seconds from now (pre-event countdown).
    * **`+M`** — M after the **endgame shrink begins** (`endgame_starts_at`).
      `clock("+2")` sits 2 minutes into the endgame, radius still near its
      widest — the mid-game state where poles at the far edge start to
      vanish but most are still capturable.
    * **`-M`** — M before the **endgame shrink ends** (`endgame_ends_at`).
      `clock("-1")` sits 1 minute from the end, radius nearly closed. `-0`
      counts as negative (the sign, not the number, picks the anchor), so
      `clock("-0")` ends the shrink right now.

  Computes the targets in Elixir and binds them — no raw SQL `NOW()`, whose
  `timestamptz` result gets timezone-shifted into the `:utc_datetime`
  columns. A `+`/`-` spec raises when no event has an endgame window.
  Returns `%{anchor: :start_time | :endgame_starts_at | :endgame_ends_at,
  direction: :before | :after, seconds: n, events: count}`.
  """
  def clock(spec) when is_binary(spec) do
    {anchor, direction, offset_seconds} = parse_clock_spec(spec)

    # `before`: the milestone lands `offset` after now (now is `offset`
    # before it). `after`: the milestone lands `offset` before now.
    signed = if direction == :before, do: offset_seconds, else: -offset_seconds
    target = DateTime.add(now(), signed, :second)

    shifted =
      Event
      |> Repo.all()
      |> Enum.count(&shift_event(&1, anchor, target))

    if anchor in [:endgame_starts_at, :endgame_ends_at] and shifted == 0 do
      raise "clock:#{spec} needs an event with an endgame window configured."
    end

    %{anchor: anchor, direction: direction, seconds: offset_seconds, events: shifted}
  end

  # The leading sign selects the anchor (and, for the endgame, the side we
  # sit on). "+" → just after the shrink begins; "-" (even "-0") → just
  # before it ends; none → before the start. The part after the dot is a
  # literal seconds count, so "0.30" is 30s and "1.05" is 65s — wall-clock
  # M.SS, not decimal minutes.
  defp parse_clock_spec("+" <> rest), do: {:endgame_starts_at, :after, spec_seconds(rest)}
  defp parse_clock_spec("-" <> rest), do: {:endgame_ends_at, :before, spec_seconds(rest)}
  defp parse_clock_spec(spec), do: {:start_time, :before, spec_seconds(spec)}

  defp spec_seconds(spec) do
    case String.split(spec, ".", parts: 2) do
      [mins] -> String.to_integer(mins) * 60
      [mins, secs] -> String.to_integer(mins) * 60 + String.to_integer(secs)
    end
  end

  # Anchor on start_time: shift the timeline so the start lands on target
  # (setting it outright if the event never had one). Anchor on an endgame
  # instant: shift so that instant lands on target, but only for events that
  # actually have an endgame — others report false (not shifted).
  defp shift_event(%Event{start_time: nil} = event, :start_time, target) do
    # Repo.update! auto-bumps updated_at, so we only set the instants here.
    event |> Ecto.Changeset.change(%{start_time: target}) |> Repo.update!()
    true
  end

  defp shift_event(event, anchor, target) do
    case Map.fetch!(event, anchor) do
      nil ->
        false

      current ->
        apply_shift(event, DateTime.diff(target, current, :second))
        true
    end
  end

  defp apply_shift(event, delta_seconds) do
    changes =
      for field <- @time_fields, current = Map.fetch!(event, field), current != nil, into: %{} do
        {field, current |> DateTime.add(delta_seconds, :second) |> DateTime.truncate(:second)}
      end

    event |> Ecto.Changeset.change(changes) |> Repo.update!()
  end

  # ── schedule (lay out the whole timeline across X minutes) ──────────
  # Fixed fractions of the total span. Unlike `clock` (which shifts an
  # existing timeline, preserving its intervals), this *sets* the timeline
  # from scratch out of a single duration.
  @schedule_fractions %{
    endgame_starts_at: {1, 2},
    liberation_starts_at: {5, 8},
    liberation_rollout_ends_at: {6, 8},
    endgame_ends_at: {1, 1}
  }

  @doc """
  Lay out the entire event timeline to run over `minutes` from now — start
  now, end (the endgame shrink end) `minutes` out — with the milestones
  spaced by fixed fractions of that span:

      start ............. 0
      endgame shrink .... 1/2
      liberation opens .. 5/8
      liberation closes . 6/8
      end (shrink ends) . 1

  So `schedule(30)` starts now, the shrink begins at 15 min, liberation
  invites roll out from 18.75 to 22.5 min, and the shrink ends at 30 min.
  Re-arms the one-shot event stamps (endgame announcement, final messages)
  so a compressed run replays them — pair with `clear` to also reset the
  per-team liberation state. An event with no endgame *location* gets a
  sensible default (the poles' centroid, wide→tight radii) so the shrink
  actually functions; one that already has a location keeps it. Returns
  `%{events, minutes, endgame_start_s, liberation_start_s,
  liberation_end_s, end_s}` (offsets in seconds from now).
  """
  def schedule(minutes) when is_integer(minutes) and minutes > 0 do
    start = now()
    total = minutes * 60
    offset = fn {num, den} -> div(total * num, den) end
    at = fn seconds -> DateTime.add(start, seconds, :second) end

    times =
      for {field, fraction} <- @schedule_fractions, into: %{start_time: start} do
        {field, at.(offset.(fraction))}
      end

    space = endgame_space_defaults()

    events = Repo.all(Event)

    Enum.each(events, fn event ->
      changes =
        times
        # Re-arm one-shot stamps so the compressed run fires them again.
        |> Map.merge(%{endgame_announced_at: nil, final_messages_sent_at: nil})
        |> Map.merge(if endgame_space_configured?(event), do: %{}, else: space)

      event |> Ecto.Changeset.change(changes) |> Repo.update!()
    end)

    %{
      events: length(events),
      minutes: minutes,
      endgame_start_s: offset.(@schedule_fractions.endgame_starts_at),
      liberation_start_s: offset.(@schedule_fractions.liberation_starts_at),
      liberation_end_s: offset.(@schedule_fractions.liberation_rollout_ends_at),
      end_s: total
    }
  end

  defp endgame_space_configured?(e) do
    not is_nil(e.endgame_latitude) and not is_nil(e.endgame_longitude) and
      not is_nil(e.endgame_initial_radius_m) and not is_nil(e.endgame_final_radius_m)
  end

  # A default endgame boundary for events that have none — centred on the
  # poles so most start inside it, closing from wide to tight.
  defp endgame_space_defaults do
    {lat, lng} = poles_centroid()

    %{
      endgame_latitude: lat,
      endgame_longitude: lng,
      endgame_initial_radius_m: 5000.0,
      endgame_final_radius_m: 30.0
    }
  end

  defp poles_centroid do
    located =
      Repo.all(
        from(p in Pole,
          where: not is_nil(p.latitude) and not is_nil(p.longitude),
          select: {p.latitude, p.longitude}
        )
      )

    case located do
      # No located poles — a plausible fallback (matches the test fixtures).
      [] ->
        {51.05, -114.09}

      coords ->
        n = length(coords)
        {slat, slng} = Enum.reduce(coords, {0.0, 0.0}, fn {la, ln}, {a, b} -> {a + la, b + ln} end)
        {slat / n, slng / n}
    end
  end

  # ── clear (fresh, uncaptured map) ───────────────────────────────────
  @doc """
  Remove ALL captures, in-progress claims, and the attack / pole-lost /
  liberation-invite notifications, and reset the liberation rollout (team
  invite stamps + answers, and the events' schedule) — a clean, uncaptured
  map. Returns `%{captures: n, in_progress: n, notifications: n,
  liberation_teams: n}`.
  """
  def clear do
    {tp, _} = Repo.delete_all(TeamPuzzlet)
    {caps, _} = Repo.delete_all(OwnershipEvent)

    {notes, _} =
      Repo.delete_all(from(n in Notification, where: n.type in ["attack", "pole_lost", "liberation_invite"]))

    {invited, _} =
      Repo.update_all(
        from(t in Team, where: not is_nil(t.liberation_invited_at) or not is_nil(t.liberation_response)),
        set: [liberation_invited_at: nil, liberation_response: nil, liberation_responded_at: nil]
      )

    # Un-schedule the rollout too — a past-dated window left behind would
    # have the announcer re-invite every team within a minute of the wipe.
    Repo.update_all(Event, set: [liberation_starts_at: nil, liberation_rollout_ends_at: nil])

    %{captures: caps, in_progress: tp, notifications: notes, liberation_teams: invited}
  end

  # ── abort (stop everything, disarm the clock) ───────────────────────
  @doc """
  A full teardown for a compressed test run: everything `clear/0` does,
  plus the things it deliberately leaves for a paired `schedule` —

    * **every** notification type, not just the three gameplay alerts
      `clear/0` drops (also `message`, `pole_contested`, `puzzlet_taken`,
      `puzzlet_withdrawn`, `liberation_joined`), and the `OrganiserMessage`
      source rows they fan out from (incl. the SYSTEM endgame broadcast);
    * the endgame timeline and its one-shot stamps (`start_time`,
      `endgame_starts_at`/`_ends_at`/`_announced_at`, `final_messages_sent_at`)
      and the relief-valve stamp, blanked on every event.

  With no timeline left to read, the (stateless, minute-polling) endgame
  and liberation announcers find nothing to fire — so no timed event
  happens. There are no in-memory timers to cancel. Returns
  `%{captures: n, in_progress: n, notifications: n, organiser_messages: n,
  liberation_teams: n, events: n}`.
  """
  def abort do
    %{captures: caps, in_progress: tp, notifications: alerts, liberation_teams: invited} = clear()

    # clear/0 removed only the three gameplay-alert types; drop whatever's
    # left (messages, contests, puzzlet-taken/withdrawn, liberation-joined)
    # so no prior run's notifications linger into the next.
    {rest, _} = Repo.delete_all(Notification)
    {messages, _} = Repo.delete_all(OrganiserMessage)

    # clear/0 unscheduled only the liberation window; blank the endgame
    # timeline, its one-shot stamps, and the relief stamp too — otherwise a
    # scheduled endgame still fires and relief mode carries over.
    {events, _} =
      Repo.update_all(Event,
        set: [
          start_time: nil,
          endgame_starts_at: nil,
          endgame_ends_at: nil,
          endgame_announced_at: nil,
          relief_started_at: nil,
          final_messages_sent_at: nil
        ]
      )

    %{
      captures: caps,
      in_progress: tp,
      notifications: alerts + rest,
      organiser_messages: messages,
      liberation_teams: invited,
      events: events
    }
  end

  # ── helpers ─────────────────────────────────────────────────────────
  defp user!(email, role) do
    Repo.get_by(User, email: email) || raise "#{role} user not found: #{email}"
  end

  defp two_word_names(count, exclude) do
    taken = MapSet.new(exclude)

    for_result = for(a <- @adjectives, n <- @nouns, do: "#{a} #{n}")

    for_result
    |> Enum.reject(&MapSet.member?(taken, &1))
    |> Enum.shuffle()
    |> Enum.take(count)
  end

  defp existing_team_names, do: Repo.all(from(t in Team, select: t.name))

  defp team_and_proposed_names do
    existing_team_names() ++
      Repo.all(from(u in User, where: not is_nil(u.proposed_team_name), select: u.proposed_team_name))
  end

  defp now, do: DateTime.truncate(DateTime.utc_now(), :second)
  defp sq(x), do: x * x
end
