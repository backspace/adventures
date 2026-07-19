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
    * clock           set the event start_time to one hour from now

  Presets expand to an ordered list of steps:

    * gameplay   = playable teams clock
    * validation = validations
    * midgame    = playable teams clock captures

  The step logic lives in `Registrations.Landgrab.Seed` (this task is a
  thin CLI over it, and `Registrations.Landgrab.SeedTest` exercises it).

  LOCAL ONLY. Refuses to run unless the Repo database looks like a
  *_dev / *_test database — it never touches a real environment (and mix
  isn't present in a release anyway).
  """
  use Mix.Task

  alias Registrations.Landgrab.Seed
  alias Registrations.Repo

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
                      validator (fills their queue; puzzlets stay validated)  (40)
      captures:N      partial gameplay — capture N poles spread across the teams,
                      with attacks, pole-losses, and in-progress claims  (20)
      clear           remove ALL captures, in-progress claims, and the attack /
                      pole-lost notifications — a clean, uncaptured map
      filler:N        create N teamless filler users with memorable proposed
                      team names — pair with 'teams' to add that many teams  (5)
      names           rename any leftover "FIXME" teams to two-word names
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
    %{assigned: assigned, validator: email} = Seed.validations(n || 40)
    Mix.shell().info("validations: assigned #{assigned} puzzlet(s) to #{email}.")
  end

  defp run_step({"captures", n}) do
    %{captured: captured, flips: flips, in_progress: in_progress} = Seed.captures(n || 20)

    Mix.shell().info(
      "captures: #{captured} pole(s) captured, #{flips} contested/flipped, " <>
        "#{in_progress} left in-progress — all via real scan→answer gameplay."
    )
  end

  defp run_step({"clear", _}) do
    %{captures: caps, in_progress: tp, notifications: notes} = Seed.clear()
    Mix.shell().info("clear: removed #{caps} capture(s), #{tp} in-progress, #{notes} gameplay notification(s).")
  end

  defp run_step({"clock", n}) do
    %{minutes: minutes} = Seed.clock(n || 60)
    Mix.shell().info("clock: event start_time set to #{minutes} minute(s) from now.")
  end

  defp run_step({"filler", n}) do
    %{created: created} = Seed.filler(n || 5)
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
