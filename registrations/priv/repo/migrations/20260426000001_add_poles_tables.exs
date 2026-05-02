defmodule Registrations.Repo.Migrations.AddPolesTables do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:poles, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:barcode, :string, null: false)
      add(:label, :string)
      add(:latitude, :float, null: false)
      add(:longitude, :float, null: false)

      timestamps()
    end

    create(unique_index(:poles, [:barcode], prefix: "poles"))

    create table(:puzzlets, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:instructions, :text, null: false)
      add(:answer, :string, null: false)
      add(:difficulty, :integer, null: false)
      add(:status, :string, null: false, default: "draft")

      add(
        :pole_id,
        references(:poles, type: :uuid, prefix: "poles", on_delete: :nilify_all)
      )

      timestamps()
    end

    create(index(:puzzlets, [:pole_id, :difficulty], prefix: "poles"))
    create(index(:puzzlets, [:status], prefix: "poles"))

    create table(:attempts, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:answer_given, :string, null: false)
      add(:correct, :boolean, null: false)

      add(
        :puzzlet_id,
        references(:puzzlets, type: :uuid, prefix: "poles", on_delete: :nilify_all),
        null: false
      )

      add(
        :team_id,
        references(:teams, type: :uuid, prefix: "public", on_delete: :nilify_all),
        null: false
      )

      add(
        :user_id,
        references(:users, type: :uuid, prefix: "public", on_delete: :nilify_all),
        null: false
      )

      timestamps()
    end

    create(index(:attempts, [:puzzlet_id, :team_id], prefix: "poles"))

    create table(:captures, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :puzzlet_id,
        references(:puzzlets, type: :uuid, prefix: "poles", on_delete: :nilify_all),
        null: false
      )

      add(
        :team_id,
        references(:teams, type: :uuid, prefix: "public", on_delete: :nilify_all),
        null: false
      )

      timestamps()
    end

    create(unique_index(:captures, [:puzzlet_id], prefix: "poles"))
    create(index(:captures, [:team_id], prefix: "poles"))
  end
end
