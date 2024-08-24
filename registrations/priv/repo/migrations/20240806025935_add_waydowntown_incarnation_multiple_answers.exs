defmodule Registrations.Repo.Migrations.AddWaydowntownIncarnationMultipleAnswers do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:incarnations, prefix: "waydowntown") do
      add(:answers, {:array, :string}, default: [])
    end
  end
end
