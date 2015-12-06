defmodule Cr2016site.User do
  use Cr2016site.Web, :model

  schema "users" do
    field :email, :string
    field :crypted_password, :string
    field :password, :string, virtual: true

    field :admin, :boolean

    field :team_emails, :string

    timestamps
  end

  @required_fields ~w(email password)
  @optional_fields ~w(team_emails)

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:email)
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 5)
  end

  def details_changeset(model, params \\ :empty) do
    model
    |> cast(params, [], @optional_fields)
  end
end
