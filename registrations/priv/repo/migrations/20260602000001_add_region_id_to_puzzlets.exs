defmodule Registrations.Repo.Migrations.AddRegionIdToPuzzlets do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:puzzlets, prefix: "poles") do
      add(
        :region_id,
        references(:regions, type: :uuid, prefix: "poles", on_delete: :nilify_all)
      )
    end

    create(index(:puzzlets, [:region_id], prefix: "poles"))
  end
end
