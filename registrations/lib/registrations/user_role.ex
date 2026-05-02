defmodule Registrations.UserRole do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @valid_roles ~w(validator validation_supervisor author)

  schema "user_roles" do
    field(:role, :string)

    belongs_to(:user, RegistrationsWeb.User, type: :binary_id)
    belongs_to(:assigned_by, RegistrationsWeb.User, type: :binary_id, foreign_key: :assigned_by_id)

    timestamps()
  end

  @doc false
  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role, :assigned_by_id])
    |> validate_required([:user_id, :role])
    |> validate_inclusion(:role, @valid_roles)
    |> unique_constraint([:user_id, :role])
    |> assoc_constraint(:user)
  end

  def valid_roles, do: @valid_roles
end
