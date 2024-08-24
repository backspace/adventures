defmodule Registrations.Repo.Migrations.AddWaydowntownIncarnations do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:incarnations, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:concept, :string)
      add(:mask, :string)
      add(:answer, :string)

      timestamps()
    end
  end
end
