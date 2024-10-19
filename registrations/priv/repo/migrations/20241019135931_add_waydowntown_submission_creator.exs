defmodule Registrations.Repo.Migrations.AddWaydowntownSubmissionCreator do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("submissions", prefix: "waydowntown") do
      add(:creator_id, references("users", prefix: "public", type: :uuid))
    end
  end
end
