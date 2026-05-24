defmodule Registrations.Poles.Capture do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Poles.Puzzlet

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "poles"

  schema "captures" do
    field(:test_session_id, :binary_id)

    belongs_to(:puzzlet, Puzzlet, type: :binary_id)
    belongs_to(:team, RegistrationsWeb.Team, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(capture, attrs) do
    capture
    |> cast(attrs, [:puzzlet_id, :team_id, :test_session_id])
    |> validate_required([:puzzlet_id])
    |> validate_team_or_test_session()
    |> assoc_constraint(:puzzlet)
    |> assoc_constraint(:team)
    |> unique_constraint(:puzzlet_id, name: :captures_puzzlet_real_unique)
    |> unique_constraint([:puzzlet_id, :test_session_id],
      name: :captures_puzzlet_test_unique
    )
    |> check_constraint(:base,
      name: :real_captures_have_team,
      message: "capture must have either a team_id or a test_session_id"
    )
  end

  defp validate_team_or_test_session(changeset) do
    team_id = get_field(changeset, :team_id)
    test_session_id = get_field(changeset, :test_session_id)

    if is_nil(team_id) and is_nil(test_session_id) do
      add_error(changeset, :base, "capture must have either team_id or test_session_id")
    else
      changeset
    end
  end
end
