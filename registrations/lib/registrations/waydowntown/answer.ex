defmodule Registrations.Waydowntown.Answer do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "answers" do
    field(:label, :string)
    field(:answer, :string)
    field(:order, :integer)

    belongs_to(:specification, Registrations.Waydowntown.Specification, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(answer, attrs) do
    answer
    |> cast(attrs, [:answer, :order, :specification_id])
    |> validate_required([:answer, :order, :specification_id])
    |> assoc_constraint(:specification)
  end
end
