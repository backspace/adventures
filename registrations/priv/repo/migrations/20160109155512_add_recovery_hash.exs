defmodule Registrations.Repo.Migrations.AddRecoveryHash do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:recovery_hash, :string)
    end
  end
end
