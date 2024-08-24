defmodule Registrations.Waydowntown.Game do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Waydowntown.Answer

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "games" do
    belongs_to(:incarnation, Registrations.Waydowntown.Incarnation, type: :binary_id)
    belongs_to(:winner_answer, Answer, type: :binary_id)
    has_many(:answers, Answer)

    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:incarnation_id, :winner_answer_id])
    |> validate_required([:incarnation_id])
    |> assoc_constraint(:incarnation)
    |> assoc_constraint(:winner_answer)
  end
end
