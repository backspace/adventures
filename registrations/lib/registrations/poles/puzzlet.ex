defmodule Registrations.Poles.Puzzlet do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Poles.Attempt
  alias Registrations.Poles.Capture
  alias Registrations.Poles.Pole

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "poles"

  schema "puzzlets" do
    field(:instructions, :string)
    field(:answer, :string)
    field(:difficulty, :integer)
    field(:status, Ecto.Enum, values: [:draft, :validated, :retired], default: :draft)

    belongs_to(:pole, Pole, type: :binary_id)

    has_many(:attempts, Attempt, on_delete: :nilify_all)
    has_one(:capture, Capture, on_delete: :nilify_all)

    timestamps()
  end

  @doc false
  def changeset(puzzlet, attrs) do
    puzzlet
    |> cast(attrs, [:instructions, :answer, :difficulty, :status, :pole_id])
    |> validate_required([:instructions, :answer, :difficulty])
    |> validate_number(:difficulty, greater_than_or_equal_to: 1)
    |> assoc_constraint(:pole)
  end
end
