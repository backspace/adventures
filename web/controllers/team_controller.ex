defmodule Cr2016site.TeamController do
  use Cr2016site.Web, :controller

  alias Cr2016site.User
  alias Cr2016site.Team

  plug Cr2016site.Plugs.Admin

  plug :scrub_params, "team" when action in [:create, :update]

  def index(conn, _params) do
    teams = Repo.all(Team)
    render(conn, "index.html", teams: teams, users: Repo.all(User))
  end

  # FIXME surely there’s a better way
  def index_json(conn, _params) do
    users = Repo.all(User)
    teams = Repo.all(Team)
    json conn, %{data: Enum.map(teams, fn(team) ->
      team_emails = Enum.map(team.user_ids, fn(user_id) ->
        user = Enum.find(users, fn(u) -> u.id == user_id end)

        if user do
          user.email
        else
          "unknown user #{user_id}"
        end
      end)
      |> Enum.join(", ")

      %{
        type: "teams",
        id: team.id,
        attributes: %{
          name: team.name,
          riskAversion: team.risk_aversion,
          notes: team.notes,
          users: team_emails
        }
      }
    end)}
  end

  def new(conn, _params) do
    changeset = Team.changeset(%Team{})
    users = Repo.all(User)
    render(conn, "new.html", users: users, changeset: changeset)
  end

  def build(conn, %{"user_id" => base_user_id}) do
    base_user = Repo.get!(User, base_user_id)
    users = Repo.all(User)

    relationships = Cr2016site.TeamFinder.relationships(base_user, users)

    team_users = [base_user] ++ relationships.mutuals

    changeset = Team.changeset(%Team{}, %{
      "name" => base_user.proposed_team_name,
      "risk_aversion" => base_user.risk_aversion,
      "user_ids" => Enum.map(team_users, fn(u) -> u.id end),
      "notes" => team_users
        |> Enum.filter_map(fn(u) -> String.trim(u.accessibility || "") != "" end, &("#{String.split(&1.email, "@") |> hd}: #{&1.accessibility}"))
        |> Enum.join(", ")
    })

    case Repo.insert(changeset) do
      {:ok, _team} ->
        conn
        |> put_flash(:info, "Team built successfully")
        |> redirect(to: user_path(conn, :index))
      {:error, _changeset} ->
        conn
        |> put_flash(:error, "An error occurred building that team!")
        |> redirect(to: user_path(conn, :index))
    end
  end

  def create(conn, %{"team" => team_params}) do
    changeset = Team.changeset(%Team{}, team_params)

    case Repo.insert(changeset) do
      {:ok, _team} ->
        conn
        |> put_flash(:info, "Team created successfully.")
        |> redirect(to: team_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    team = Repo.get!(Team, id)
    render(conn, "show.html", team: team)
  end

  def edit(conn, %{"id" => id}) do
    team = Repo.get!(Team, id)
    users = Repo.all(User)
    changeset = Team.changeset(team)
    render(conn, "edit.html", team: team, users: users, changeset: changeset)
  end

  def update(conn, %{"id" => id, "team" => team_params}) do
    team = Repo.get!(Team, id)
    users = Repo.all(User)
    changeset = Team.changeset(team, team_params)

    case Repo.update(changeset) do
      {:ok, team} ->
        conn
        |> put_flash(:info, "Team updated successfully.")
        |> redirect(to: team_path(conn, :show, team))
      {:error, changeset} ->
        render(conn, "edit.html", users: users, team: team, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    team = Repo.get!(Team, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(team)

    conn
    |> put_flash(:info, "Team deleted successfully.")
    |> redirect(to: team_path(conn, :index))
  end
end
