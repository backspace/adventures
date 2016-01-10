defmodule Cr2016site.Message do
  use Cr2016site.Web, :model

  schema "messages" do
    field :subject, :string
    field :content, :string
    field :rendered_content, :string
    field :ready, :boolean, default: false
    field :postmarked_at, Ecto.Date

    timestamps
  end

  @required_fields ~w(subject content ready postmarked_at)
  @optional_fields ~w(rendered_content)

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
