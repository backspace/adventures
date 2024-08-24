defmodule Registrations.Waydowntown.Region do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "regions" do
    field(:description, :string)
    field(:name, :string)

    belongs_to(:parent, __MODULE__, type: :binary_id, foreign_key: :parent_id)

    timestamps()
  end

  @doc false
  def changeset(region, attrs) do
    region
    |> cast(attrs, [:name, :description])
    |> validate_required([:name, :description])
  end
end
