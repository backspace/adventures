defmodule AdventureRegistrationsWeb.Team do
  use AdventureRegistrationsWeb, :model

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "teams" do
    field :name, :string
    field :risk_aversion, :integer
    field :notes, :string
    field :user_ids, {:array, :binary_id}

    timestamps()
  end

  @required_fields ~w(name risk_aversion)a
  @optional_fields ~w(notes user_ids)a

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
