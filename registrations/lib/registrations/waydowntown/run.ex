defmodule Registrations.Waydowntown.Run do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Waydowntown.Participation
  alias Registrations.Waydowntown.Submission

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "runs" do
    has_many(:participations, Participation, on_delete: :delete_all)

    belongs_to(:specification, Registrations.Waydowntown.Specification, type: :binary_id)
    has_many(:submissions, Submission, on_delete: :delete_all)

    belongs_to(:winner_submission, Submission, type: :binary_id)

    field(:started_at, :utc_datetime_usec)

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
