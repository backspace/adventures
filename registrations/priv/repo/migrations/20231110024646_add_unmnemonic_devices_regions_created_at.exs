defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesRegionsCreatedAt do
  use Ecto.Migration

  def change do
    alter table("regions", prefix: "unmnemonic_devices") do
      add(:inserted_at, :utc_datetime, default: fragment("now()"))
    end
  end
end
