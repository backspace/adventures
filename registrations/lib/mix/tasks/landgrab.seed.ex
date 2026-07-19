defmodule Mix.Tasks.Landgrab.Seed do
  @shortdoc "Seed the local dev DB into a scenario (composable steps + presets)."
  @moduledoc """
  Shapes the LOCAL dev database into a testing scenario, composed from
  small, idempotent steps that run through the domain — never raw SQL that
  can silently drift from the schema.

      mix landgrab.seed gameplay
      mix landgrab.seed midgame captures:30
      mix landgrab.seed validation
      mix landgrab.seed playable teams captures:15 validations:10

  Steps (N is a count; a sensible default applies when omitted):

    * playable        validate every draft/in_review puzzlet and attach the
                      loose (non-validator-only) ones to their nearest pole
    * teams           build teams for teamless users (mix landgrab.build_teams)
    * validations:N   assign N validated, uncaptured puzzlets to the test
                      validator (in_review + assigned); idempotent
    * captures:N      partial gameplay — capture N poles spread across the
                      teams, with a few active attacks and in-progress puzzlets
    * clock           set the event start_time to one hour from now

  Presets expand to an ordered list of steps:

    * gameplay   = playable teams clock
    * validation = validations
    * midgame    = playable teams clock captures

  LOCAL ONLY. Refuses to run unless the Repo database looks like a
  *_dev / *_test database — it never touches a real environment (and mix
  isn't present in a release anyway).
  """
  use Mix.Task

  import Ecto.Query

  alias Registrations.Landgrab.Capture
  alias Registrations.Landgrab.Notification
  alias Registrations.Landgrab.Pole
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.TeamPuzzlet
  alias Registrations.Landgrab.Validations
  alias Registrations.Landgrab.Validations.PuzzletValidation
  alias Registrations.Repo
  alias RegistrationsWeb.Team
  alias RegistrationsWeb.User

  @validator_email "buck.doyle+validator@gmail.com"
  @assigner_email "b@chromatin.ca"

  @presets %{
    "gameplay" => ~w(playable teams clock),
    "validation" => ~w(validations),
    "midgame" => ~w(playable teams clock captures),
    "kickoff" => ~w(clear playable teams clock:0)
  }

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    guard_not_production!()

    case expand(args) do
      [] ->
        Mix.shell().info(help())

      steps ->
        Enum.each(steps, &run_step/1)
        Mix.shell().info("Done.")
    end
  end

  defp help do
    """
    mix landgrab.seed — shape the LOCAL dev database into a scenario.

    Usage: ADVENTURE=landgrab mix landgrab.seed <preset|step[:N]> ...
    Steps run left to right; presets expand to steps.

    Presets:
      gameplay     playable + teams + clock             (ready to play, pre-event)
      midgame      playable + teams + clock + captures  (a game already unfolding)
      validation   validations                          (fills the validator queue)
      kickoff      clear + playable + teams + clock:0    (fresh map, game just begun)

    Steps  (N is a number; the default is shown in parens):
      playable        validate every draft/in_review puzzlet and attach loose
                      (non-validator-only) ones to their nearest pole
      teams           build teams for every teamless user
      validations:N   assign N validated, uncaptured puzzlets to the test
                      validator, as in_review + assigned  (40)
      captures:N      partial gameplay — capture N poles spread across the teams,
                      with attacks, pole-losses, and in-progress claims  (20)
      clear           remove ALL captures, in-progress claims, and the attack /
                      pole-lost notifications — a clean, uncaptured map
      clock:N         set the event start to N minutes from now  (60)
                        clock:1  → a one-minute countdown
                        clock:0  → started right now

    Examples:
      ADVENTURE=landgrab mix landgrab.seed gameplay
      ADVENTURE=landgrab mix landgrab.seed midgame captures:30
      ADVENTURE=landgrab mix landgrab.seed clear clock:1
      ADVENTURE=landgrab mix landgrab.seed kickoff
    """
  end

  # ── argument parsing ────────────────────────────────────────────────
  # Each arg is a step (`captures:30`) or a preset that expands to steps.
  defp expand(args) do
    Enum.flat_map(args, fn arg ->
      {name, count} = parse(arg)

      case Map.get(@presets, name) do
        nil -> [{name, count}]
        steps -> Enum.map(steps, &parse/1)
      end
    end)
  end

  defp parse(arg) do
    case String.split(arg, ":", parts: 2) do
      [name, n] -> {name, String.to_integer(n)}
      [name] -> {name, nil}
    end
  end

  defp run_step({"playable", _}), do: playable()
  defp run_step({"teams", _}), do: teams()
  defp run_step({"validations", n}), do: validations(n || 40)
  defp run_step({"captures", n}), do: captures(n || 20)
  defp run_step({"clear", _}), do: clear()
  defp run_step({"clock", n}), do: clock(n || 60)
  defp run_step({other, _}), do: Mix.raise("Unknown step or preset: #{inspect(other)}")

  # ── playable ────────────────────────────────────────────────────────
  defp playable do
    {validated, _} =
      Repo.update_all(
        from(z in Puzzlet, where: z.status in [:draft, :in_review]),
        set: [status: :validated, updated_at: now()]
      )

    attached = attach_loose_puzzlets()
    Mix.shell().info("playable: validated #{validated} puzzlet(s), attached #{attached} to poles.")
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
  defp teams, do: Mix.Task.rerun("landgrab.build_teams", [])

  # ── validations ─────────────────────────────────────────────────────
  defp validations(n) do
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

    Mix.shell().info("validations: assigned #{assigned} puzzlet(s) to #{validator.email}.")
  end

  # ── captures (partial gameplay) ─────────────────────────────────────
  defp captures(n) do
    teams = teams_with_members()

    if teams == [] do
      Mix.raise("captures needs teams — run the 'teams' step first (or the 'midgame' preset).")
    end

    owned = capture_poles(teams, n)
    attacks = seed_attacks(owned, teams)
    flips = seed_flips(owned, teams)
    in_progress = seed_in_progress(teams)

    Mix.shell().info(
      "captures: #{length(owned)} pole(s) owned across #{length(teams)} team(s), " <>
        "#{attacks} attack(s), #{flips} pole-loss(es), #{in_progress} in-progress."
    )
  end

  # Capture one uncaptured puzzlet per still-unowned pole, round-robining
  # teams so ownership spreads into a contested map.
  defp capture_poles(teams, n) do
    captured = from(c in Capture, select: c.puzzlet_id)
    owned_poles = from(c in Capture, join: z in Puzzlet, on: z.id == c.puzzlet_id, select: z.pole_id)

    from(z in Puzzlet,
      join: p in Pole,
      on: p.id == z.pole_id,
      where: z.status == :validated and not z.validator_only,
      where: z.id not in subquery(captured),
      where: z.pole_id not in subquery(owned_poles),
      select: %{pole_id: p.id, pole_label: p.label, puzzlet_id: z.id}
    )
    |> Repo.all()
    |> Enum.uniq_by(& &1.pole_id)
    |> Enum.take(n)
    |> Enum.with_index()
    |> Enum.map(fn {cand, i} ->
      team = Enum.at(teams, rem(i, length(teams)))

      {:ok, _} =
        %Capture{}
        |> Capture.changeset(%{puzzlet_id: cand.puzzlet_id, team_id: team.id})
        |> Repo.insert()

      Map.put(cand, :team, team)
    end)
  end

  # A few of the freshly-owned poles get an incoming attack from another
  # team — a real Notification, so the inbox/unread state is populated too.
  defp seed_attacks(_owned, teams) when length(teams) < 2, do: 0

  defp seed_attacks(owned, teams) do
    owned
    |> Enum.take(max(1, div(length(owned), 4)))
    |> Enum.reduce(0, fn o, acc ->
      attacker = Enum.find(teams, fn t -> t.id != o.team.id end)

      result =
        %Notification{}
        |> Notification.changeset(%{
          type: "attack",
          recipient_team_id: o.team.id,
          sender_team_id: attacker.id,
          body: "#{attacker.name} is attacking #{o.pole_label || "a pole"}.",
          metadata: %{
            "pole_id" => o.pole_id,
            "pole_label" => o.pole_label,
            "sender_team_name" => attacker.name
          }
        })
        |> Repo.insert()

      case result do
        {:ok, _} -> acc + 1
        _ -> acc
      end
    end)
  end

  # Flip a few freshly-owned poles to another team by capturing a second
  # puzzlet on them (the later capture wins ownership) — which is exactly
  # what generates a "pole lost" notification to the previous owner, so the
  # inbox reflects notifications real gameplay would already have sent.
  defp seed_flips(_owned, teams) when length(teams) < 2, do: 0

  defp seed_flips(owned, teams) do
    owned
    |> Enum.take(max(1, div(length(owned), 4)))
    |> Enum.reduce(0, fn o, acc ->
      with %{} = new_owner <- Enum.find(teams, &(&1.id != o.team.id)),
           puzzlet_id when is_binary(puzzlet_id) <- uncaptured_puzzlet_on_pole(o.pole_id) do
        {:ok, _} =
          %Capture{}
          |> Capture.changeset(%{puzzlet_id: puzzlet_id, team_id: new_owner.id})
          |> Repo.insert()

        %Notification{}
        |> Notification.changeset(%{
          type: "pole_lost",
          recipient_team_id: o.team.id,
          sender_team_id: new_owner.id,
          body: "#{new_owner.name} took #{o.pole_label || "a pole"}.",
          metadata: %{
            "pole_id" => o.pole_id,
            "pole_label" => o.pole_label,
            "sender_team_name" => new_owner.name
          }
        })
        |> Repo.insert()

        acc + 1
      else
        _ -> acc
      end
    end)
  end

  defp uncaptured_puzzlet_on_pole(pole_id) do
    Repo.one(
      from(z in Puzzlet,
        where: z.pole_id == ^pole_id and z.status == :validated and not z.validator_only,
        where: z.id not in subquery(from(c in Capture, select: c.puzzlet_id)),
        select: z.id,
        limit: 1
      )
    )
  end

  # Put a handful of teams mid-puzzlet (an active, unresolved claim).
  defp seed_in_progress(teams) do
    from(z in Puzzlet,
      join: p in Pole,
      on: p.id == z.pole_id,
      where: z.status == :validated and not z.validator_only,
      where: z.id not in subquery(from(c in Capture, select: c.puzzlet_id)),
      where: z.id not in subquery(from(tp in TeamPuzzlet, select: tp.puzzlet_id)),
      select: %{pole_id: p.id, puzzlet_id: z.id}
    )
    |> Repo.all()
    |> Enum.take(length(teams))
    |> Enum.with_index()
    |> Enum.reduce(0, fn {cand, i}, acc ->
      team = Enum.at(teams, rem(i, length(teams)))

      result =
        %TeamPuzzlet{}
        |> TeamPuzzlet.changeset(%{
          team_id: team.id,
          puzzlet_id: cand.puzzlet_id,
          pole_id: cand.pole_id,
          started_by_user_id: team.member_id
        })
        |> Repo.insert()

      case result do
        {:ok, _} -> acc + 1
        _ -> acc
      end
    end)
  end

  # ── clock ───────────────────────────────────────────────────────────
  defp clock(minutes) do
    Repo.query!("UPDATE landgrab.events SET start_time = NOW() + $1 * INTERVAL '1 minute'", [minutes])
    Mix.shell().info("clock: event start_time set to #{minutes} minute(s) from now.")
  end

  # ── clear (fresh, uncaptured map) ───────────────────────────────────
  defp clear do
    {tp, _} = Repo.delete_all(TeamPuzzlet)
    {caps, _} = Repo.delete_all(Capture)
    {notes, _} = Repo.delete_all(from(n in Notification, where: n.type in ["attack", "pole_lost"]))

    Mix.shell().info("clear: removed #{caps} capture(s), #{tp} in-progress, #{notes} gameplay notification(s).")
  end

  # ── helpers ─────────────────────────────────────────────────────────
  defp teams_with_members do
    Repo.all(
      from(t in Team,
        join: u in User,
        on: u.team_id == t.id,
        distinct: t.id,
        select: %{id: t.id, name: t.name, member_id: u.id}
      )
    )
  end

  defp user!(email, role) do
    case Repo.get_by(User, email: email) do
      nil -> Mix.raise("#{role} user not found: #{email}")
      user -> user
    end
  end

  defp guard_not_production! do
    db = to_string(Repo.config()[:database] || "")

    unless String.ends_with?(db, "_dev") or String.ends_with?(db, "_test") do
      Mix.raise("""
      landgrab.seed refuses to run: this is a LOCAL/dev-only scenario seeder.
        MIX_ENV=#{Mix.env()}, database=#{inspect(db)}
      It only runs against a *_dev / *_test database, never a real environment.
      """)
    end
  end

  defp now, do: DateTime.truncate(DateTime.utc_now(), :second)
  defp sq(x), do: x * x
end
