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

    has_many(:puzzlets, Puzzlet, on_delete: :nilify_all)

    timestamps()
  end

  @doc false
  def changeset(pole, attrs) do
    pole
    |> cast(attrs, [:barcode, :label, :latitude, :longitude])
    |> validate_required([:barcode, :latitude, :longitude])
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> unique_constraint(:barcode)
  end
end
