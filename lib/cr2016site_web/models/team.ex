defmodule Cr2016siteWeb.Team do
  use Cr2016siteWeb, :model

  schema "teams" do
    field :name, :string
    field :risk_aversion, :integer
    field :notes, :string
    field :user_ids, {:array, :integer}

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
    |> cast(params, @required_fields, @optional_fields)
  end
end
