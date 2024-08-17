defmodule Registrations.Waydowntown.Answer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "answers" do
    field(:answer, :string)
    field(:correct, :boolean, default: false)
    field(:game, :id)

    timestamps()
  end

  @doc false
  def changeset(answer, attrs) do
    answer
    |> cast(attrs, [:answer, :correct])
    |> validate_required([:answer, :correct])
  end
end
