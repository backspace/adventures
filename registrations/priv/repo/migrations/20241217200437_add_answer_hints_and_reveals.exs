defmodule Registrations.Repo.Migrations.AddAnswerHintsAndReveals do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:answers, prefix: "waydowntown") do
      add(:hint, :text, null: true)
    end

    create table(:reveals, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:answer_id, references(:answers, type: :uuid, on_delete: :nilify_all))
      add(:run_id, references(:runs, type: :uuid, on_delete: :nilify_all))
      add(:user_id, references(:users, prefix: "public", type: :uuid, on_delete: :nilify_all))

      timestamps(updated_at: false)
    end
  end
end
