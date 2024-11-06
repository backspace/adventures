defmodule Registrations.Waydowntown.Specification do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Waydowntown

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "specifications" do
    field(:concept, :string)
    field(:start_description, :string)
    field(:task_description, :string)
    field(:duration, :integer)
    field(:notes, :string)

    belongs_to(:region, Registrations.Waydowntown.Region, type: :binary_id)
    belongs_to(:creator, RegistrationsWeb.User, type: :binary_id, foreign_key: :creator_id)

    has_many(:answers, Registrations.Waydowntown.Answer, on_delete: :delete_all)
    has_many(:runs, Registrations.Waydowntown.Run, on_delete: :delete_all)

    timestamps()
  end

  @doc false
  def changeset(specification, attrs) do
    specification
    |> cast(attrs, [:concept, :start_description, :task_description, :duration, :region_id, :creator_id, :notes])
    |> validate_required([:concept, :task_description])
    |> validate_concept()
    |> validate_number(:duration, greater_than: 0)
    |> assoc_constraint(:region)
    |> assoc_constraint(:creator)
  end

  defp validate_concept(changeset) do
    validate_change(changeset, :concept, fn :concept, concept ->
      if concept in Waydowntown.get_known_concepts() do
        []
      else
        [concept: "must be a known concept"]
      end
    end)
  end
end
