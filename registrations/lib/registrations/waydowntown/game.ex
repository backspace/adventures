defmodule Registrations.Waydowntown.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "games" do
    belongs_to(:incarnation, Registrations.Waydowntown.Incarnation, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:incarnation_id])
    |> validate_required([:incarnation_id])
    |> assoc_constraint(:incarnation)
  end
end
