defmodule Registrations.Repo.Migrations.AddWaydowntownIncarnationStart do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:incarnations, prefix: "waydowntown") do
      add(:start, :text, null: true)
    end
  end
end
