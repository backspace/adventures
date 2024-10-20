defmodule Registrations.Waydowntown.Participation do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Waydowntown.Run

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "participations" do
    belongs_to(:run, Run, type: :binary_id)
    belongs_to(:user, RegistrationsWeb.User, type: :binary_id)

    field(:ready_at, :utc_datetime_usec)

    timestamps()
  end

  @doc false
  def changeset(participation, attrs) do
    participation
    |> cast(attrs, [:ready_at, :run_id, :user_id])
    |> assoc_constraint(:run)
    |> assoc_constraint(:user)
  end
end
