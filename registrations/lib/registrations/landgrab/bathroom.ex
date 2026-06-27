defmodule Registrations.Landgrab.Bathroom do
  @moduledoc """
  Author-published point of interest for players who need a restroom
  during the adventure. No validation lifecycle — created by authors,
  immediately visible to everyone. Optional region linkage so a bathroom
  inside a building can inherit the region's accessibility / entry
  instructions.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Landgrab.AccessibilityTag
  alias Registrations.Landgrab.Region

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "landgrab"

  schema "bathrooms" do
    field(:name, :string)
    field(:latitude, :float)
    field(:longitude, :float)
    field(:accuracy_m, :float)
    field(:notes, :string)
    field(:accessibility_tags, {:array, :string}, default: [])
    field(:accessibility_notes, :string)
    field(:entry_instructions, :string)

    belongs_to(:region, Region, type: :binary_id)
    belongs_to(:creator, RegistrationsWeb.User, type: :binary_id, foreign_key: :creator_id)

    timestamps()
  end

  @doc false
  def changeset(bathroom, attrs) do
    bathroom
    |> cast(attrs, [
      :name,
      :latitude,
      :longitude,
      :accuracy_m,
      :notes,
      :accessibility_tags,
      :accessibility_notes,
      :entry_instructions,
      :region_id,
      :creator_id
    ])
    |> validate_required([:latitude, :longitude])
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:accuracy_m, greater_than_or_equal_to: 0)
    |> validate_subset(:accessibility_tags, AccessibilityTag.all())
    |> assoc_constraint(:region)
    |> assoc_constraint(:creator)
  end
end
