defmodule Registrations.Landgrab.Region do
  @moduledoc """
  A region groups puzzlets that share accessibility characteristics or
  entry instructions. Regions nest via `parent_region_id` so structures
  like "777 Main St > 4th floor > Server room" can each carry their own
  notes; puzzlet rendering walks the ancestor chain to compose the full
  accessibility picture.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Landgrab.AccessibilityTag

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "landgrab"

  schema "regions" do
    field(:name, :string)
    field(:accessibility_tags, {:array, :string}, default: [])
    field(:accessibility_notes, :string)
    field(:entry_instructions, :string)

    belongs_to(:parent_region, __MODULE__, type: :binary_id, foreign_key: :parent_region_id)
    belongs_to(:creator, RegistrationsWeb.User, type: :binary_id, foreign_key: :creator_id)

    has_many(:children, __MODULE__, foreign_key: :parent_region_id)

    timestamps()
  end

  @doc false
  def changeset(region, attrs) do
    region
    |> cast(attrs, [
      :name,
      :accessibility_tags,
      :accessibility_notes,
      :entry_instructions,
      :parent_region_id,
      :creator_id
    ])
    |> validate_required([:name])
    |> validate_subset(:accessibility_tags, AccessibilityTag.all())
    |> validate_no_self_parent()
  end

  defp validate_no_self_parent(changeset) do
    case {get_field(changeset, :id), get_field(changeset, :parent_region_id)} do
      {nil, _} -> changeset
      {_, nil} -> changeset
      {id, id} -> add_error(changeset, :parent_region_id, "cannot be itself")
      _ -> changeset
    end
  end
end
