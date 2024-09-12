defmodule Registrations.Repo.Migrations.AddWaydowntownTables do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:regions, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:name, :string)
      add(:description, :text)
      add(:geom, :geometry)

      add(:parent_id, references(:regions, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create table(:specifications, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:concept, :string)
      add(:start_description, :text)
      add(:task_description, :text)
      add(:duration, :integer, null: true)

      add(:region_id, references(:regions, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create table(:answers, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:label, :text)
      add(:answer, :text)
      add(:order, :integer, null: true)

      add(:specification_id, references(:specifications, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create table(:runs, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:specification_id, references(:specifications, type: :uuid, on_delete: :nilify_all))
      add(:started_at, :utc_datetime_usec, null: true)

      timestamps()
    end

    create table(:submissions, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:answer, :text)
      add(:correct, :boolean)

      add(:run_id, references(:runs, type: :uuid, on_delete: :nilify_all))
      add(:answer_id, references(:answers, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    alter table(:runs, prefix: "waydowntown") do
      add(:winner_submission_id, references(:submissions, type: :uuid, on_delete: :nilify_all))
    end
  end
end
