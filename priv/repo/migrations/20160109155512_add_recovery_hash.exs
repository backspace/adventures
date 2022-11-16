defmodule AdventureRegistrations.Repo.Migrations.AddRecoveryHash do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:recovery_hash, :string)
    end
  end
end
