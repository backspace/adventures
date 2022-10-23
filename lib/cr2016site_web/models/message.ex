defmodule Cr2016siteWeb.Message do
  use Cr2016siteWeb, :model

  schema "messages" do
    field :subject, :string
    field :content, :string
    field :rendered_content, :string
    field :ready, :boolean, default: false
    field :show_team, :boolean, default: false
    field :postmarked_at, :date

    timestamps()
  end

  @required_fields ~w(subject content ready show_team postmarked_at)a
  @optional_fields ~w(rendered_content)a

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
