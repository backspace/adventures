defmodule Registrations.Poles.Capture do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Poles.Puzzlet

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "poles"

  schema "captures" do
    belongs_to(:puzzlet, Puzzlet, type: :binary_id)
    belongs_to(:team, RegistrationsWeb.Team, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(capture, attrs) do
    capture
    |> cast(attrs, [:puzzlet_id, :team_id])
    |> validate_required([:puzzlet_id, :team_id])
    |> assoc_constraint(:puzzlet)
    |> assoc_constraint(:team)
    |> unique_constraint(:puzzlet_id)
  end
end
