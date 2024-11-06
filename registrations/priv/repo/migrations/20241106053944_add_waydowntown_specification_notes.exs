defmodule Registrations.Repo.Migrations.AddWaydowntownSpecificationNotes do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("specifications", prefix: "waydowntown") do
      add(:notes, :text)
    end
  end
end
