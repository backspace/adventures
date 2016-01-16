defmodule Cr2016site.User do
  use Cr2016site.Web, :model

  schema "users" do
    field :email, :string
    field :crypted_password, :string
    field :password, :string, virtual: true
    field :recovery_hash, :string

    field :new_password, :string, virtual: true
    field :new_password_confirmation, :string, virtual: true
    field :current_password, :string, virtual: true

    field :admin, :boolean

    field :team_emails, :string
    field :proposed_team_name, :string

    field :risk_aversion, :integer
    field :accessibility, :string

    field :comments, :string
    field :source, :string

    timestamps
  end

  @required_fields ~w(email password)
  @optional_fields ~w(team_emails proposed_team_name risk_aversion accessibility comments source)

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

  def account_changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(current_password new_password new_password_confirmation), [])
    # FIXME duplicated from changeset
    |> validate_length(:new_password, min: 5)
    |> validate_confirmation(:new_password)
  end

  def deletion_changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(current_password), [])
  end

  def reset_changeset(model) do
    if model do
      model
      |> cast(%{}, [], ~w(recovery_hash))
    end
  end

  def perform_reset_changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(recovery_hash new_password new_password_confirmation), [])
    |> validate_length(:new_password, min: 5)
    |> validate_confirmation(:new_password)
  end
end
