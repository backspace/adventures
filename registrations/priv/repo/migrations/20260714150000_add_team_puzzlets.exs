defmodule Registrations.Repo.Migrations.AddTeamPuzzlets do
  @moduledoc false
  use Ecto.Migration

  def change do
    # A team's currently-active puzzlet(s) — the puzzlet a member
    # scanned and the team is now working on. Persisted so the app
    # can resume after being killed, so every team member sees it
    # without rescanning, and so rival teams can be notified when the
    # puzzlet they were working on is captured out from under them.
    #
    # Rows exist only while active: they're deleted when the puzzlet
    # is captured (by this team or another), when the team locks
    # itself out, or when the team gives up. Capacity (how many a
    # team may hold at once) is enforced in code.
    create table("team_puzzlets", primary_key: false, prefix: "landgrab") do
      add(:id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:team_id, references("teams", prefix: "public", type: :binary_id, on_delete: :delete_all), null: false)
      add(:puzzlet_id, references("puzzlets", prefix: "landgrab", type: :binary_id, on_delete: :delete_all), null: false)
      add(:pole_id, references("poles", prefix: "landgrab", type: :binary_id, on_delete: :delete_all), null: false)
      add(:started_by_user_id, references("users", prefix: "public", type: :binary_id, on_delete: :nilify_all))
      timestamps()
    end

    # One active row per (team, puzzlet).
    create(unique_index("team_puzzlets", [:team_id, :puzzlet_id], prefix: "landgrab"))
    # Contention lookup: who else is working this puzzlet?
    create(index("team_puzzlets", [:puzzlet_id], prefix: "landgrab"))
    create(index("team_puzzlets", [:team_id], prefix: "landgrab"))
  end
end
