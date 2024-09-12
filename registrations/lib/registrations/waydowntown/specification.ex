defmodule Registrations.Waydowntown.Specification do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "specifications" do
    field(:concept, :string)
    field(:start_description, :string)
    field(:task_description, :string)
    field(:duration, :integer)

    belongs_to(:region, Registrations.Waydowntown.Region, type: :binary_id)

    has_many(:answers, Registrations.Waydowntown.Answer, on_delete: :delete_all)
    has_many(:runs, Registrations.Waydowntown.Run, on_delete: :delete_all)

    timestamps()
  end

  @doc false
  def changeset(specification, attrs) do
    specification
    |> cast(attrs, [:concept, :start_description, :task_description, :duration, :region_id])
    |> validate_required([:concept, :start_description, :task_description, :duration])
  end
end
