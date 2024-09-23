defmodule Registrations.Repo.Migrations.AddWaydowntownSpecificationCreator do
  use Ecto.Migration

  def change do
    alter table("specifications", prefix: "waydowntown") do
      add(:creator_id, references("users", prefix: "public", type: :uuid))
    end
  end
end
