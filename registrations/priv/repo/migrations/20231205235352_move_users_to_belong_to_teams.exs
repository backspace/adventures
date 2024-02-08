defmodule Registrations.Repo.Migrations.MoveUsersToBelongToTeams do
  use Ecto.Migration

  alias Registrations.Repo
  alias RegistrationsWeb.Team

  def up do
    alter table(:users) do
      add(:team_id, references(:teams, type: :uuid, on_delete: :nilify_all))
    end

    execute("""
      UPDATE users
      SET team_id = teams.id
      FROM teams
      WHERE users.id = ANY(teams.user_ids);
    """)

    alter table(:teams) do
      remove(:user_ids)
    end
  end

  def down do
    alter table(:teams) do
      add(:user_ids, {:array, :uuid}, default: [])
    end

    execute("""
      UPDATE teams
      SET user_ids = subquery.user_ids
      FROM (
        SELECT
          t.id AS team_id,
          ARRAY_AGG(u.id) AS user_ids
        FROM
          teams t
          INNER JOIN users u ON t.id = u.team_id
        GROUP BY
          t.id
      ) AS subquery
      WHERE teams.id = subquery.team_id;
    """)

    alter table(:users) do
      remove(:team_id)
    end
  end
end
