defmodule Registrations.Repo.Migrations.AddPolesEventsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:events, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:name, :string, null: false)
      add(:start_time, :utc_datetime)

      timestamps()
    end
  end
end
