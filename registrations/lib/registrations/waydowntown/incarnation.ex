defmodule Registrations.Waydowntown.Incarnation do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "incarnations" do
    field(:answers, {:array, :string})
    field(:concept, :string)
    field(:mask, :string)
    field(:placed, :boolean, default: true)
    field(:start, :string)

    belongs_to(:region, Registrations.Waydowntown.Region, type: :binary_id)
    has_many(:games, Registrations.Waydowntown.Game)

    timestamps()
  end

  @doc false
  def changeset(incarnation, attrs) do
    incarnation
    |> cast(attrs, [:concept, :mask, :answers, :placed, :region_id])
    |> validate_required([:concept, :mask, :answers, :placed])
  end
end
