defmodule Registrations.Poles.Attempt do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Poles.Puzzlet

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "poles"

  schema "attempts" do
    field(:answer_given, :string)
    field(:correct, :boolean)

    belongs_to(:puzzlet, Puzzlet, type: :binary_id)
    belongs_to(:team, RegistrationsWeb.Team, type: :binary_id)
    belongs_to(:user, RegistrationsWeb.User, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(attempt, attrs) do
    attempt
    |> cast(attrs, [:answer_given, :correct, :puzzlet_id, :team_id, :user_id])
    |> validate_required([:answer_given, :correct, :puzzlet_id, :team_id, :user_id])
    |> assoc_constraint(:puzzlet)
    |> assoc_constraint(:team)
    |> assoc_constraint(:user)
  end
end
