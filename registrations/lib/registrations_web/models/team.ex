defmodule RegistrationsWeb.Team do
  @moduledoc false
  use RegistrationsWeb, :model

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "teams" do
    field(:name, :string)
    field(:risk_aversion, :integer)
    field(:notes, :string)
    field(:voicepass, :string)
    # Short, human-typable code teammates use to join this team (scanned
    # from a QR "team card" or typed). Server-generated, never user-set.
    field(:join_code, :string)

    has_many(:users, RegistrationsWeb.User)

    timestamps()
  end

  @required_fields ~w(name risk_aversion)a
  @optional_fields ~w(notes voicepass)a

  # Unambiguous alphabet — no 0/O/1/I/L — so a code read off a printed
  # card can't be mistyped between look-alike characters.
  @code_alphabet ~c"ABCDEFGHJKMNPQRSTUVWXYZ23456789"
  @code_length 6

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> put_join_code()
    |> unique_constraint(:join_code)
  end

  # Assign a join code on first insert; leave an existing one untouched.
  defp put_join_code(changeset) do
    if get_field(changeset, :join_code) do
      changeset
    else
      put_change(changeset, :join_code, generate_join_code())
    end
  end

  defp generate_join_code do
    Enum.map(1..@code_length, fn _ -> Enum.random(@code_alphabet) end)
    |> List.to_string()
  end
end
