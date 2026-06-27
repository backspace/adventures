defmodule Registrations.Landgrab.Puzzlet do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Landgrab.AccessibilityTag
  alias Registrations.Landgrab.Attempt
  alias Registrations.Landgrab.Capture
  alias Registrations.Landgrab.Pole
  alias Registrations.Landgrab.Region

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "landgrab"

  schema "puzzlets" do
    field(:instructions, :string)
    field(:answer, :string)
    field(:difficulty, :integer)
    field(:status, Ecto.Enum, values: [:draft, :in_review, :validated, :retired], default: :draft)

    field(:answer_type, Ecto.Enum,
      values: [:loose_text, :strict_text, :barcode, :nfc],
      default: :loose_text
    )

    field(:latitude, :float)
    field(:longitude, :float)
    field(:accuracy_m, :float)

    field(:accessibility_tags, {:array, :string}, default: [])
    field(:accessibility_notes, :string)

    field(:warning, :string)

    belongs_to(:pole, Pole, type: :binary_id)
    belongs_to(:region, Region, type: :binary_id)
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
      :answer_type,
      :difficulty,
      :status,
      :pole_id,
      :region_id,
      :creator_id,
      :latitude,
      :longitude,
      :accuracy_m,
      :accessibility_tags,
      :accessibility_notes,
      :warning
    ])
    |> validate_required([:instructions, :answer, :difficulty])
    |> validate_number(:difficulty, greater_than_or_equal_to: 1)
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:accuracy_m, greater_than_or_equal_to: 0)
    |> validate_subset(:accessibility_tags, AccessibilityTag.all())
    |> assoc_constraint(:pole)
    |> assoc_constraint(:region)
    |> assoc_constraint(:creator)
  end
end
