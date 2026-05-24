defmodule Registrations.Repo.Migrations.AddWarningToPuzzlets do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:puzzlets, prefix: "poles") do
      add(:warning, :text)
    end
  end
end
