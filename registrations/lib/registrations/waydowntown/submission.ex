defmodule Registrations.Waydowntown.Submission do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "submissions" do
    field(:submission, :string)
    field(:correct, :boolean)

    belongs_to(:creator, RegistrationsWeb.User, type: :binary_id, foreign_key: :creator_id)
    belongs_to(:run, Registrations.Waydowntown.Run, type: :binary_id)
    belongs_to(:answer, Registrations.Waydowntown.Answer, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(submission, attrs) do
    submission
    |> cast(attrs, [:submission, :correct, :creator_id, :run_id, :answer_id])
    |> validate_required([:submission, :correct, :creator_id, :run_id])
    |> assoc_constraint(:creator)
    |> assoc_constraint(:run)
    |> assoc_constraint(:answer)
  end
end
