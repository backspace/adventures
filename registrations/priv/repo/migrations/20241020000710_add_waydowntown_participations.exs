defmodule Registrations.Repo.Migrations.AddWaydowntownParticipations do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:participations, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:user_id, references("users", prefix: "public", type: :uuid, on_delete: :delete_all))
      add(:run_id, references(:runs, type: :uuid, on_delete: :delete_all))

      add(:ready_at, :utc_datetime_usec, null: true)

      timestamps()
    end
  end
end
