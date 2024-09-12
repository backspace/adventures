defmodule Registrations.Waydowntown.Run do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "runs" do
    belongs_to(:specification, Registrations.Waydowntown.Specification, type: :binary_id)
    has_many(:answers, Registrations.Waydowntown.Answer)

    field(:started_at, :utc_datetime_usec)

    belongs_to(:winner_submission, Registrations.Waydowntown.Submission, type: :binary_id)

    field(:custom_error, :string, virtual: true)

    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:specification_id, :winner_submission_id, :started_at, :custom_error])
    |> validate_required([:specification_id])
    |> assoc_constraint(:specification)
    |> assoc_constraint(:winner_submission)
    |> validate_custom_error()
  end

  defp validate_custom_error(changeset) do
    case get_change(changeset, :custom_error) do
      nil -> changeset
      error -> add_error(changeset, :base, error)
    end
  end
end
