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
    field(:status, Ecto.Enum, values: [:draft, :in_review, :validated, :retired], default: :draft)

    field(:latitude, :float)
    field(:longitude, :float)
    field(:accuracy_m, :float)

    belongs_to(:pole, Pole, type: :binary_id)
    belongs_to(:creator, RegistrationsWeb.User, type: :binary_id, foreign_key: :creator_id)

    has_many(:attempts, Attempt, on_delete: :nilify_all)
    has_one(:capture, Capture, on_delete: :nilify_all)

    timestamps()
  end

  @doc false
  def changeset(puzzlet, attrs) do
    puzzlet
    |> cast(attrs, [
      :instructions,
      :answer,
      :difficulty,
      :status,
      :pole_id,
      :creator_id,
      :latitude,
      :longitude,
      :accuracy_m
    ])
    |> validate_required([:instructions, :answer, :difficulty])
    |> validate_number(:difficulty, greater_than_or_equal_to: 1)
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:accuracy_m, greater_than_or_equal_to: 0)
    |> assoc_constraint(:pole)
    |> assoc_constraint(:creator)
  end
end
