defmodule Registrations.Repo.Migrations.CreateUserRoles do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:user_roles, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:user_id, references("users", type: :uuid, on_delete: :delete_all), null: false)
      add(:role, :string, null: false)
      add(:assigned_by_id, references("users", type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create(unique_index(:user_roles, [:user_id, :role]))
  end
end
