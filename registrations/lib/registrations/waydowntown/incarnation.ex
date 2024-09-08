defmodule Registrations.Waydowntown.Incarnation do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "incarnations" do
    field(:answers, {:array, :string})
    field(:concept, :string)
    field(:description, :string)
    field(:duration_seconds, :integer)
    field(:placed, :boolean, default: true)
    field(:start, :string)

    belongs_to(:region, Registrations.Waydowntown.Region, type: :binary_id)
    has_many(:games, Registrations.Waydowntown.Game)

    timestamps()
  end

  @doc false
  def changeset(incarnation, attrs) do
    incarnation
    |> cast(attrs, [:concept, :description, :answers, :placed, :region_id, :start, :duration_seconds])
    |> validate_required([:concept, :description, :answers, :placed])
  end
end
