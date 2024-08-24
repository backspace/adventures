defmodule Registrations.Repo.Migrations.AddWaydowntownGames do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:games, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:incarnation_id, references("incarnations", type: :uuid))

      timestamps()
    end
  end
end
