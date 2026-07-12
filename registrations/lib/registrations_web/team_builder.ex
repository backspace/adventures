defmodule RegistrationsWeb.TeamBuilder do
  @moduledoc """
  Builds a team around a base user: the user plus everyone
  `TeamFinder` considers a mutual, named from the base user's
  proposed team name. This is the logic behind the admin users
  page's per-user "Build" button; `mix landgrab.build_teams` reuses
  it to sweep every teamless user (for local/rehearsal databases).
  """
  import Ecto.Query

  alias Registrations.Repo
  alias RegistrationsWeb.Team
  alias RegistrationsWeb.TeamFinder
  alias RegistrationsWeb.User

  @doc """
  Create a team for `base_user` and assign them + their mutuals to
  it. Returns `{:ok, team, used_fallbacks?}` where `used_fallbacks?`
  signals that name and/or risk aversion were placeholders, or
  `{:error, changeset}`.
  """
  def build_for(%User{} = base_user) do
    users = Repo.all(User)
    relationships = TeamFinder.relationships(base_user, users)
    team_users = [base_user] ++ relationships.mutuals

    changeset =
      Team.changeset(%Team{}, %{
        "name" => base_user.proposed_team_name || "FIXME",
        "risk_aversion" => base_user.risk_aversion || 1
      })

    fallbacks = !base_user.proposed_team_name && !base_user.risk_aversion

    case Repo.insert(changeset) do
      {:ok, team} ->
        team_user_ids = Enum.map(team_users, fn user -> user.id end)

        Repo.update_all(
          from(u in User, where: u.id in ^team_user_ids, update: [set: [team_id: ^team.id]]),
          []
        )

        {:ok, team, fallbacks}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
