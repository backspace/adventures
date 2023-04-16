defmodule AdventureRegistrationsWeb.Message do
  use AdventureRegistrationsWeb, :model

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "messages" do
    field(:subject, :string)
    field(:content, :string)
    field(:from_name, :string)
    field(:from_address, :string)
    field(:rendered_content, :string)
    field(:ready, :boolean, default: false)
    field(:show_team, :boolean, default: false)
    field(:postmarked_at, :date)

    timestamps()
  end

  @required_fields ~w(subject content ready show_team postmarked_at)a
  @optional_fields ~w(rendered_content from_name from_address)a

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
