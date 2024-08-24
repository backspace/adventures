defmodule Registrations.Repo.Migrations.AddWaydowntownRegions do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:regions, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:name, :string)
      add(:description, :text)
      add(:parent_id, references("regions", type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    alter(table(:incarnations, prefix: "waydowntown")) do
      add(:region_id, references("regions", type: :uuid, on_delete: :nilify_all), null: false)
    end
  end
end
