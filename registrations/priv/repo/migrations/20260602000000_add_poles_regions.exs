defmodule Registrations.Repo.Migrations.AddPolesRegions do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:regions, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:name, :string, null: false)
      add(:accessibility_tags, {:array, :string}, default: [], null: false)
      add(:accessibility_notes, :text)
      add(:entry_instructions, :text)

      add(
        :parent_region_id,
        references(:regions, type: :uuid, prefix: "poles", on_delete: :nilify_all)
      )

      add(
        :creator_id,
        references(:users, type: :uuid, prefix: "public", on_delete: :nilify_all)
      )

      timestamps()
    end

    create(index(:regions, [:parent_region_id], prefix: "poles"))
    create(index(:regions, [:name], prefix: "poles"))
  end
end
