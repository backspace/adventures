defmodule Registrations.Repo.Migrations.AddMessageFrom do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add(:from_name, :string)
      add(:from_address, :string)
    end
  end
end
