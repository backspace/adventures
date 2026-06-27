defmodule Registrations.Landgrab.TestSession do
  @moduledoc """
  A single tester's dry-run session. Owned by a validator or supervisor;
  scopes attempts and captures so they don't affect the real game.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @schema_prefix "landgrab"
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "test_sessions" do
    field(:name, :string)
    field(:ended_at, :utc_datetime)
    field(:creator_id, :binary_id)

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:name, :ended_at, :creator_id])
    |> validate_required([:creator_id])
  end
end
