defmodule Registrations.Waydowntown.Answer do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "answers" do
    field(:label, :string)
    field(:answer, :string)
    field(:hint, :string)
    field(:order, :integer)

    belongs_to(:specification, Registrations.Waydowntown.Specification, type: :binary_id)
    belongs_to(:region, Registrations.Waydowntown.Region, type: :binary_id)

    has_many(:reveals, Registrations.Waydowntown.Reveal, on_delete: :delete_all)

    timestamps()
  end

  @ordered_concepts ~w(orientation_memory cardinal_memory)

  @doc false
  def changeset(answer, attrs) do
    changeset =
      answer
      |> cast(attrs, [:answer, :order, :specification_id, :region_id, :label, :hint])
      |> validate_required([:answer, :specification_id])
      |> assoc_constraint(:specification)
      |> assoc_constraint(:region)

    if requires_order?(answer, changeset) do
      validate_required(changeset, [:order])
    else
      changeset
    end
  end

  defp requires_order?(answer, changeset) do
    concept =
      cond do
        answer.specification && answer.specification.__struct__ != Ecto.Association.NotLoaded ->
          answer.specification.concept

        true ->
          spec_id = get_field(changeset, :specification_id)

          if spec_id do
            Registrations.Repo.get(Registrations.Waydowntown.Specification, spec_id)
            |> case do
              nil -> nil
              spec -> spec.concept
            end
          end
      end

    concept in @ordered_concepts
  end
end
