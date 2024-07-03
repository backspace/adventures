defmodule Registrations.Repo.Migrations.AddWaydowntownAnswers do
  use Ecto.Migration

  def change do
    create table(:answers, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:answer, :string)
      add(:game_id, references("games", type: :uuid))

      timestamps()
    end
  end
end
