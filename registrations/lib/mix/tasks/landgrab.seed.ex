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
    * teams           build teams for teamless users through the team builder
    * validations:N   assign N validated, uncaptured puzzlets to the test
                      validator to fill their queue; idempotent
    * captures:N      partial gameplay — capture N poles spread across the
                      teams, with a few active attacks and in-progress puzzlets
    * clock:M[.SS]    put "now" M min SS sec before the start (.SS = seconds);
                      a negative spec anchors on the endgame shrink end instead

  Presets expand to an ordered list of steps:

    * gameplay   = playable teams clock
    * validation = validations
    * midgame    = playable teams clock:5 captures clock:+2
                   (seed captures pre-event, then sit "now" just after the
                   endgame begins — a game in flight; see the note by @presets)

  The step logic lives in `Registrations.Landgrab.Seed` (this task is a
  thin CLI over it, and `Registrations.Landgrab.SeedTest` exercises it).

  LOCAL ONLY. Refuses to run unless the Repo database looks like a
  *_dev / *_test database — it never touches a real environment (and mix
  isn't present in a release anyway).
  """
  use Mix.Task

  alias Registrations.Landgrab.Seed
  alias Registrations.Repo

  # midgame: clock:5 first parks "now" pre-event so the endgame radius is
  # NOT enforced while captures are seeded (scan/answer would otherwise be
  # refused as "outside the zone" whenever the clock is already mid-endgame
  # — e.g. re-running midgame). Then captures play through real gameplay,
  # and clock:+2 drops "now" just after the shrink begins — a game in
  # flight, poles at the far edge starting to vanish. The two clock steps
  # are the price of a deterministic capture set regardless of the clock's
  # prior state; the preset expansion is echoed at run time so they read as
  # intentional, not redundant.
  @presets %{
    "gameplay" => ~w(playable teams clock),
    "validation" => ~w(validations),
    "midgame" => ~w(playable teams clock:5 captures clock:+2),
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
        announce_presets(args)
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
      gameplay     playable + teams + clock                     (ready to play, pre-event)
      midgame      playable + teams + clock:5 + captures + clock:+2   (a game in flight, endgame just begun)
      validation   validations                                  (fills the validator queue)
      kickoff      clear + playable + teams + clock:0           (fresh map, game just begun)

    Steps  (N is a number; the default is shown in parens):
      playable        validate every draft/in_review puzzlet and attach loose
                      (non-validator-only) ones to their nearest pole
      teams           build teams for every teamless user
      validations:N   assign N validated, uncaptured puzzlets to the test
                      validator (fills their queue; puzzlets stay validated)  (40)
      captures:N      partial gameplay — capture N poles spread across the teams,
                      with attacks, pole-losses, and in-progress claims  (20)
      clear           remove ALL captures, in-progress claims, and the attack /
                      pole-lost notifications — a clean, uncaptured map
      filler:N        create N teamless filler users with memorable proposed
                      team names — pair with 'teams' to add that many teams  (5)
      names           rename any leftover "FIXME" teams to two-word names
      clock:M[.SS]    put "now" M min SS sec before the event START, shifting
                      the whole timeline to match  (.SS is seconds, so
                      0.30 = 30s; default 60). The sign picks the milestone:
                        clock:1     → 1 minute before the start
                        clock:0.30  → 30 seconds before the start
                        clock:0     → started right now
      clock:+M[.SS]   put "now" that far AFTER the endgame SHRINK BEGINS —
                      radius still wide, most poles still capturable
                        clock:+2    → 2 minutes into the endgame
      clock:-M[.SS]   put "now" that far BEFORE the endgame SHRINK ENDS —
                      radius nearly closed  (+/- need an endgame window)
                        clock:-1    → 1 minute before the shrink ends
                        clock:-0.30 → 30 seconds before the shrink ends
                        clock:-0    → shrink ends right now

    Examples:
      ADVENTURE=landgrab mix landgrab.seed gameplay
      ADVENTURE=landgrab mix landgrab.seed midgame captures:30
      ADVENTURE=landgrab mix landgrab.seed clear clock:1
      ADVENTURE=landgrab mix landgrab.seed kickoff
    """
  end

  # Echo each preset's expansion before running, so the steps it stands for
  # (e.g. midgame's two clock moves) read as intentional, not redundant.
  defp announce_presets(args) do
    for arg <- args, steps = Map.get(@presets, arg) do
      Mix.shell().info("#{arg} → #{Enum.join(steps, " ")}")
    end
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

  # Keep the raw count string — clock needs "0.30" / "-0" verbatim; the
  # integer steps convert with count/2 at the call site.
  defp parse(arg) do
    case String.split(arg, ":", parts: 2) do
      [name, n] -> {name, n}
      [name] -> {name, nil}
    end
  end

  defp count(nil, default), do: default
  defp count(raw, _default), do: String.to_integer(raw)

  defp format_offset(seconds) do
    case {div(seconds, 60), rem(seconds, 60)} do
      {0, s} -> "#{s}s"
      {m, 0} -> "#{m}m"
      {m, s} -> "#{m}m #{s}s"
    end
  end

  # ── steps: run through Registrations.Landgrab.Seed, then report ─────
  defp run_step({"playable", _}) do
    %{validated: v, attached: a} = Seed.playable()
    Mix.shell().info("playable: validated #{v} puzzlet(s), attached #{a} to poles.")
  end

  defp run_step({"teams", _}) do
    %{built: built} = Seed.teams()
    Mix.shell().info("teams: built #{built} team(s) for teamless users.")
  end

  defp run_step({"validations", n}) do
    %{assigned: assigned, validator: email} = Seed.validations(count(n, 40))
    Mix.shell().info("validations: assigned #{assigned} puzzlet(s) to #{email}.")
  end

  defp run_step({"captures", n}) do
    %{captured: captured, flips: flips, in_progress: in_progress} = Seed.captures(count(n, 20))

    Mix.shell().info(
      "captures: #{captured} pole(s) captured, #{flips} contested/flipped, " <>
        "#{in_progress} left in-progress — all via real scan→answer gameplay."
    )
  end

  defp run_step({"clear", _}) do
    %{captures: caps, in_progress: tp, notifications: notes} = Seed.clear()
    Mix.shell().info("clear: removed #{caps} capture(s), #{tp} in-progress, #{notes} gameplay notification(s).")
  end

  defp run_step({"clock", spec}) do
    %{anchor: anchor, direction: direction, seconds: seconds, events: events} = Seed.clock(spec || "60")

    milestone =
      case anchor do
        :endgame_starts_at -> "endgame shrink start"
        :endgame_ends_at -> "endgame shrink end"
        :start_time -> "start"
      end

    Mix.shell().info(
      "clock: now set #{format_offset(seconds)} #{direction} the #{milestone} across #{events} event(s)."
    )
  end

  defp run_step({"filler", n}) do
    %{created: created} = Seed.filler(count(n, 5))
    Mix.shell().info("filler: created #{created} teamless filler user(s) — run 'teams' to build their teams.")
  end

  defp run_step({"names", _}) do
    %{renamed: renamed} = Seed.names()
    Mix.shell().info("names: renamed #{renamed} FIXME team(s).")
  end

  defp run_step({other, _}), do: Mix.raise("Unknown step or preset: #{inspect(other)}")

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
end
