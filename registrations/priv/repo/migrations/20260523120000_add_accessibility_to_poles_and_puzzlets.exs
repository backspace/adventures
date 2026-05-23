defmodule Registrations.Repo.Migrations.AddAccessibilityToPolesAndPuzzlets do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:poles, prefix: "poles") do
      add(:accessibility_tags, {:array, :string}, default: [], null: false)
      add(:accessibility_notes, :text)
    end

    alter table(:puzzlets, prefix: "poles") do
      add(:accessibility_tags, {:array, :string}, default: [], null: false)
      add(:accessibility_notes, :text)
    end
  end
end
