defmodule Registrations.Repo.Migrations.CreateUser do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:email, :string)
      add(:crypted_password, :string)

      timestamps()
    end

    create(unique_index(:users, [:email]))
  end
end
