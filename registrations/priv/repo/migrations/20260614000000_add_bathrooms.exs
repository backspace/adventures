defmodule Registrations.Repo.Migrations.AddBathrooms do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:bathrooms, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:name, :string)
      add(:latitude, :float, null: false)
      add(:longitude, :float, null: false)
      add(:accuracy_m, :float)
      add(:notes, :text)
      add(:accessibility_tags, {:array, :string}, default: [], null: false)
      add(:accessibility_notes, :text)
      add(:entry_instructions, :text)

      add(
        :region_id,
        references(:regions, type: :uuid, prefix: "poles", on_delete: :nilify_all)
      )

      add(
        :creator_id,
        references(:users, type: :uuid, prefix: "public", on_delete: :nilify_all)
      )

      timestamps()
    end

    create(index(:bathrooms, [:region_id], prefix: "poles"))
    create(index(:bathrooms, [:creator_id], prefix: "poles"))
  end
end
