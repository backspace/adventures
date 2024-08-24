defmodule Registrations.Repo.Migrations.AddAdminColumn do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:admin, :boolean)
    end
  end
end
