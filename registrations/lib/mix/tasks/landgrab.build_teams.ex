defmodule Mix.Tasks.Landgrab.BuildTeams do
  @shortdoc "Assign every teamless user to a team via the admin team-builder"
  @moduledoc """
  Sweeps all users without a team and builds teams for them using
  `RegistrationsWeb.TeamBuilder` — the same logic as the admin users
  page's "Build" button, so mutual team-email proposals group
  together and loners get single-member teams with placeholder
  names.

  Intended for local/rehearsal databases after a content sync
  (`landgrab-copy.sh` offers to run it); harmless to re-run since it
  only touches teamless users.
  """
  use Mix.Task

  import Ecto.Query

  alias Registrations.Repo
  alias RegistrationsWeb.User

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    built = sweep(0)
    remaining = Repo.aggregate(from(u in User, where: is_nil(u.team_id)), :count)
    Mix.shell().info("Built #{built} teams; #{remaining} users still teamless.")
  end

  # Each build_for call may absorb several users (the base user's
  # mutuals), so re-query after every build rather than iterating a
  # snapshot of the teamless list.
  defp sweep(built) do
    case Repo.one(from(u in User, where: is_nil(u.team_id), order_by: u.inserted_at, limit: 1)) do
      nil ->
        built

      user ->
        case RegistrationsWeb.TeamBuilder.build_for(user) do
          {:ok, team, fallbacks} ->
            note = if fallbacks, do: " (placeholder name)", else: ""
            Mix.shell().info("  #{user.email} → #{team.name}#{note}")
            sweep(built + 1)

          {:error, changeset} ->
            Mix.raise("Failed to build team for #{user.email}: #{inspect(changeset.errors)}")
        end
    end
  end
end
