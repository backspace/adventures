defmodule Registrations.Repo.Migrations.AddWaydowntownAnswerRegion do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:answers, prefix: "waydowntown") do
      add(:region_id, references(:regions, type: :uuid, on_delete: :nilify_all))
    end
  end
end
