defmodule Registrations.Landgrab.TeamPuzzlet do
  @moduledoc """
  A team's active puzzlet — set when a member scans a pole and is
  served its puzzlet, cleared when the puzzlet resolves (captured by
  anyone, locked out, or given up). See `Registrations.Landgrab` for
  the assign/resolve logic and the capacity rule.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "landgrab"

  schema "team_puzzlets" do
    belongs_to(:team, RegistrationsWeb.Team, type: :binary_id)
    belongs_to(:puzzlet, Registrations.Landgrab.Puzzlet, type: :binary_id)
    belongs_to(:pole, Registrations.Landgrab.Pole, type: :binary_id)
    belongs_to(:started_by, RegistrationsWeb.User, type: :binary_id, foreign_key: :started_by_user_id)

    timestamps()
  end

  @doc false
  def changeset(team_puzzlet, attrs) do
    team_puzzlet
    |> cast(attrs, [:team_id, :puzzlet_id, :pole_id, :started_by_user_id])
    |> validate_required([:team_id, :puzzlet_id, :pole_id])
    |> unique_constraint([:team_id, :puzzlet_id])
  end
end
