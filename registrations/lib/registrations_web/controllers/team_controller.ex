defmodule RegistrationsWeb.TeamController do
  use RegistrationsWeb, :controller

  alias RegistrationsWeb.Team
  alias RegistrationsWeb.User

  plug RegistrationsWeb.Plugs.Admin

  plug :scrub_params, "team" when action in [:create, :update]

  def index(conn, _params) do
    teams = Team |> Repo.all() |> Repo.preload(:users)
    render(conn, "index.html", teams: teams)
  end

  # Printable sheet of team cards (name + join code + QR) for handing out
  # to walk-up groups on the day.
  def cards(conn, _params) do
    teams = Team |> Repo.all() |> Enum.sort_by(&(&1.name || ""))
    render(conn, "cards.html", teams: teams)
  end

  # FIXME surely there’s a better way
  def index_json(conn, _params) do
    teams = Team |> Repo.all() |> Repo.preload(:users)

    json(conn, %{
      data:
        Enum.map(teams, fn team ->
          team_emails = RegistrationsWeb.SharedHelpers.team_emails(team)

          user_notes =
            Enum.reduce(team.users, "\n", fn user, notes ->
              if user && user.accessibility && String.length(user.accessibility) > 0 do
                "#{notes}\n#{user.email}: #{user.accessibility}"
              else
                notes
              end
            end)

          team_attributes = %{
            name: team.name,
            riskAversion: team.risk_aversion,
            notes: "#{team.notes}#{user_notes}",
            users: team_emails,
            createdAt: team.inserted_at,
            updatedAt: team.updated_at
          }

          team_attributes =
            if Application.get_env(:registrations, :adventure) == "unmnemonic-devices",
              do: Map.put(team_attributes, :identifier, team.voicepass),
              else: team_attributes

          %{
            type: "teams",
            id: team.id,
            attributes: team_attributes
          }
        end)
    })
  end

  def new(conn, _params) do
    # Pre-fill risk aversion with 1 so the creation form defaults to it
    # (the operator can still change it before submitting).
    changeset = Team.changeset(%Team{risk_aversion: 1})
    render(conn, "new.html", changeset: changeset)
  end

  def build(conn, %{"user_id" => base_user_id}) do
    base_user = Repo.get!(User, base_user_id)

    case RegistrationsWeb.TeamBuilder.build_for(base_user) do
      {:ok, _team, fallbacks} ->
        flash_type =
          if fallbacks do
            :error
          else
            :info
          end

        flash_message =
          if fallbacks do
            "Team built with placeholders!"
          else
            "Team built successfully"
          end

        conn
        |> put_flash(flash_type, flash_message)
        |> redirect(to: Routes.user_path(conn, :index))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "An error occurred building that team!")
        |> redirect(to: Routes.user_path(conn, :index))
    end
  end

  def create(conn, %{"team" => team_params}) do
    changeset = Team.changeset(%Team{}, team_params)

    case Repo.insert(changeset) do
      {:ok, _team} ->
        conn
        |> put_flash(:info, "Team created successfully.")
        |> redirect(to: Routes.team_path(conn, :index))

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    team = Team |> Repo.get!(id) |> Repo.preload(:users)
    render(conn, "show.html", team: team)
  end

  def edit(conn, %{"id" => id}) do
    team = Team |> Repo.get!(id) |> Repo.preload(:users)
    changeset = Team.changeset(team)
    {teamless, teamed} = addable_users(team)

    render(conn, "edit.html",
      team: team,
      changeset: changeset,
      teamless_users: teamless,
      teamed_users: teamed
    )
  end

  # People the admin can add, split for the dropdown: those with no team
  # (offered first) and those on another team (adding one moves them here).
  # This team's own members are excluded — they're already listed above. Each
  # group is sorted alphabetically by email.
  defp addable_users(team) do
    by_email = &Enum.sort_by(&1, fn u -> String.downcase(u.email || "") end)
    users = Repo.all(User)

    teamless = users |> Enum.filter(&is_nil(&1.team_id)) |> then(by_email)

    teamed =
      users
      |> Enum.filter(&(not is_nil(&1.team_id) and &1.team_id != team.id))
      |> then(by_email)

    {teamless, teamed}
  end

  # Add a member picked from the dropdown (by id) — the admin counterpart to a
  # player joining with the team code. A member on another team is moved here.
  def add_member(conn, %{"id" => id, "member" => %{"user_id" => user_id}})
      when user_id != "" do
    team = Repo.get!(Team, id)

    case Repo.get(User, user_id) do
      nil ->
        conn
        |> put_flash(:error, "That person could not be found.")
        |> redirect(to: Routes.team_path(conn, :edit, team))

      %User{team_id: team_id} when team_id == team.id and not is_nil(team_id) ->
        conn
        |> put_flash(:info, "That person is already on this team.")
        |> redirect(to: Routes.team_path(conn, :edit, team))

      user ->
        user |> Ecto.Changeset.change(team_id: team.id) |> Repo.update!()

        conn
        |> put_flash(:info, "#{user.email} added to the team.")
        |> redirect(to: Routes.team_path(conn, :edit, team))
    end
  end

  # No one selected (the blank prompt).
  def add_member(conn, %{"id" => id}) do
    team = Repo.get!(Team, id)

    conn
    |> put_flash(:error, "Choose a person to add.")
    |> redirect(to: Routes.team_path(conn, :edit, team))
  end

  # Remove a member from the team (clears their team_id, leaving the account
  # intact and teamless).
  def remove_member(conn, %{"id" => id, "user_id" => user_id}) do
    team = Repo.get!(Team, id)
    user = Repo.get!(User, user_id)

    if user.team_id == team.id do
      user |> Ecto.Changeset.change(team_id: nil) |> Repo.update!()

      conn
      |> put_flash(:info, "#{user.email} removed from the team.")
      |> redirect(to: Routes.team_path(conn, :edit, team))
    else
      conn
      |> put_flash(:error, "That user isn't on this team.")
      |> redirect(to: Routes.team_path(conn, :edit, team))
    end
  end

  def update(conn, %{"id" => id, "team" => team_params}) do
    team = Repo.get!(Team, id)
    changeset = Team.changeset(team, team_params)

    case Repo.update(changeset) do
      {:ok, team} ->
        conn
        |> put_flash(:info, "Team updated successfully.")
        |> redirect(to: Routes.team_path(conn, :show, team))

      {:error, changeset} ->
        render(conn, "edit.html", team: team, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    team = Repo.get!(Team, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(team)

    conn
    |> put_flash(:info, "Team deleted successfully.")
    |> redirect(to: Routes.team_path(conn, :index))
  end
end
