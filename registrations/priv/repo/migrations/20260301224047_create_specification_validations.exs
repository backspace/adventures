defmodule Registrations.Repo.Migrations.CreateSpecificationValidations do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:specification_validations, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:specification_id, references(:specifications, type: :uuid, on_delete: :delete_all), null: false)
      add(:validator_id, references("users", prefix: "public", type: :uuid, on_delete: :delete_all), null: false)
      add(:assigned_by_id, references("users", prefix: "public", type: :uuid, on_delete: :nilify_all), null: false)

      add(:status, :string, null: false, default: "assigned")
      add(:play_mode, :string)
      add(:overall_notes, :text)

      add(:run_id, references(:runs, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create(unique_index(:specification_validations, [:specification_id, :validator_id], prefix: "waydowntown"))
  end
end
