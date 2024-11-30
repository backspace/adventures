defmodule Registrations.Repo.Migrations.AddUserNames do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:name, :string)
    end
  end
end
