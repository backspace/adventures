defmodule Registrations.Poles.Pole do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Poles.Puzzlet

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "poles"

  schema "poles" do
    field(:barcode, :string)
    field(:label, :string)
    field(:latitude, :float)
    field(:longitude, :float)
    field(:notes, :string)
    field(:accuracy_m, :float)
    field(:status, Ecto.Enum, values: [:draft, :validated, :retired], default: :draft)

    belongs_to(:creator, RegistrationsWeb.User, type: :binary_id, foreign_key: :creator_id)

    has_many(:puzzlets, Puzzlet, on_delete: :nilify_all)

    timestamps()
  end

  @doc false
  def changeset(pole, attrs) do
    pole
    |> cast(attrs, [:barcode, :label, :latitude, :longitude, :notes, :accuracy_m, :status, :creator_id])
    |> validate_required([:barcode, :latitude, :longitude])
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:accuracy_m, greater_than_or_equal_to: 0)
    |> unique_constraint(:barcode)
    |> assoc_constraint(:creator)
  end
end
