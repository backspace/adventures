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
  alias Registrations.Landgrab.Capture
  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Notification
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

    captured = from(c in Capture, select: c.puzzlet_id)

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
    unowned_capturable_poles(length(players))
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
  # puzzlet — the ones a first-wave scan can capture.
  defp unowned_capturable_poles(n) do
    owned = from(c in Capture, join: z in Puzzlet, on: z.id == c.puzzlet_id, select: z.pole_id)

    from(p in Pole,
      join: z in Puzzlet,
      on: z.pole_id == p.id,
      where: z.status == :validated and not z.validator_only,
      where: z.id not in subquery(from(c in Capture, select: c.puzzlet_id)),
      where: p.id not in subquery(owned),
      distinct: p.id,
      select: %{pole_id: p.id, barcode: p.barcode}
    )
    |> Repo.all()
    |> Enum.take(n)
  end

  # ── clock ───────────────────────────────────────────────────────────
  @doc """
  Set every event's start_time to N minutes from now. Computes the target
  in Elixir and binds it — no raw SQL `NOW()`, whose `timestamptz` result
  gets timezone-shifted when stored into the `:utc_datetime` column.
  Returns `%{minutes: n, events: count}`.
  """
  def clock(minutes) do
    start = DateTime.utc_now() |> DateTime.add(minutes * 60, :second) |> DateTime.truncate(:second)
    {events, _} = Repo.update_all(Event, set: [start_time: start, updated_at: now()])
    %{minutes: minutes, events: events}
  end

  # ── clear (fresh, uncaptured map) ───────────────────────────────────
  @doc """
  Remove ALL captures, in-progress claims, and the attack / pole-lost
  notifications — a clean, uncaptured map. Returns
  `%{captures: n, in_progress: n, notifications: n}`.
  """
  def clear do
    {tp, _} = Repo.delete_all(TeamPuzzlet)
    {caps, _} = Repo.delete_all(Capture)
    {notes, _} = Repo.delete_all(from(n in Notification, where: n.type in ["attack", "pole_lost"]))

    %{captures: caps, in_progress: tp, notifications: notes}
  end

  # ── helpers ─────────────────────────────────────────────────────────
  defp user!(email, role) do
    Repo.get_by(User, email: email) || raise "#{role} user not found: #{email}"
  end

  defp two_word_names(count, exclude) do
    taken = MapSet.new(exclude)

    for(a <- @adjectives, n <- @nouns, do: "#{a} #{n}")
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
