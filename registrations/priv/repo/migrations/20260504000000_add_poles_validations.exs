defmodule Registrations.Repo.Migrations.AddPolesValidations do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:pole_validations, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:status, :string, null: false, default: "assigned")
      add(:overall_notes, :text)

      add(
        :pole_id,
        references(:poles, type: :uuid, prefix: "poles", on_delete: :delete_all),
        null: false
      )

      add(
        :validator_id,
        references(:users, type: :uuid, prefix: "public", on_delete: :nilify_all),
        null: false
      )

      add(
        :assigned_by_id,
        references(:users, type: :uuid, prefix: "public", on_delete: :nilify_all),
        null: false
      )

      timestamps()
    end

    create(index(:pole_validations, [:pole_id], prefix: "poles"))
    create(index(:pole_validations, [:validator_id], prefix: "poles"))
    create(index(:pole_validations, [:status], prefix: "poles"))

    create table(:pole_validation_comments, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:field, :string, null: false)
      add(:comment, :text)
      add(:suggested_value, :text)
      add(:status, :string, null: false, default: "pending")

      add(
        :pole_validation_id,
        references(:pole_validations, type: :uuid, prefix: "poles", on_delete: :delete_all),
        null: false
      )

      timestamps()
    end

    create(index(:pole_validation_comments, [:pole_validation_id], prefix: "poles"))

    create table(:puzzlet_validations, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:status, :string, null: false, default: "assigned")
      add(:overall_notes, :text)

      add(
        :puzzlet_id,
        references(:puzzlets, type: :uuid, prefix: "poles", on_delete: :delete_all),
        null: false
      )

      add(
        :validator_id,
        references(:users, type: :uuid, prefix: "public", on_delete: :nilify_all),
        null: false
      )

      add(
        :assigned_by_id,
        references(:users, type: :uuid, prefix: "public", on_delete: :nilify_all),
        null: false
      )

      timestamps()
    end

    create(index(:puzzlet_validations, [:puzzlet_id], prefix: "poles"))
    create(index(:puzzlet_validations, [:validator_id], prefix: "poles"))
    create(index(:puzzlet_validations, [:status], prefix: "poles"))

    create table(:puzzlet_validation_comments, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:field, :string, null: false)
      add(:comment, :text)
      add(:suggested_value, :text)
      add(:status, :string, null: false, default: "pending")

      add(
        :puzzlet_validation_id,
        references(:puzzlet_validations, type: :uuid, prefix: "poles", on_delete: :delete_all),
        null: false
      )

      timestamps()
    end

    create(index(:puzzlet_validation_comments, [:puzzlet_validation_id], prefix: "poles"))
  end
end
