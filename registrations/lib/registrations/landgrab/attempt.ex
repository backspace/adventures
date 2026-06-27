defmodule Registrations.Landgrab.Attempt do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Landgrab.Puzzlet

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "landgrab"

  schema "attempts" do
    field(:answer_given, :string)
    field(:correct, :boolean)
    field(:test_session_id, :binary_id)

    belongs_to(:puzzlet, Puzzlet, type: :binary_id)
    belongs_to(:team, RegistrationsWeb.Team, type: :binary_id)
    belongs_to(:user, RegistrationsWeb.User, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(attempt, attrs) do
    attempt
    |> cast(attrs, [
      :answer_given,
      :correct,
      :puzzlet_id,
      :team_id,
      :user_id,
      :test_session_id
    ])
    |> validate_required([:answer_given, :correct, :puzzlet_id, :user_id])
    |> validate_team_or_test_session()
    |> assoc_constraint(:puzzlet)
    |> assoc_constraint(:team)
    |> assoc_constraint(:user)
    |> check_constraint(:base,
      name: :real_attempts_have_team,
      message: "attempt must have either a team_id or a test_session_id"
    )
  end

  defp validate_team_or_test_session(changeset) do
    team_id = get_field(changeset, :team_id)
    test_session_id = get_field(changeset, :test_session_id)

    if is_nil(team_id) and is_nil(test_session_id) do
      add_error(changeset, :base, "attempt must have either team_id or test_session_id")
    else
      changeset
    end
  end
end
