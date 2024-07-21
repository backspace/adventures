defmodule Registrations.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    rename(table(:users), :crypted_password, to: :password_hash)

    alter table(:users) do
      modify(:email, :string, null: false)
    end
  end
end
