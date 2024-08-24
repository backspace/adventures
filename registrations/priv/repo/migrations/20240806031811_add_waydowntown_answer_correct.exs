defmodule Registrations.Repo.Migrations.AddWaydowntownAnswerCorrect do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:answers, prefix: "waydowntown") do
      add(:correct, :boolean, default: false)
    end
  end
end
