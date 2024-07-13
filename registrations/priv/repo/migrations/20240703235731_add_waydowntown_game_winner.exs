defmodule Registrations.Repo.Migrations.AddWaydowntownGameWinner do
  use Ecto.Migration

  def change do
    alter table(:games, prefix: "waydowntown") do
      add(:winner_answer_id, references(:answers, type: :uuid, on_delete: :nilify_all))
    end
  end
end
