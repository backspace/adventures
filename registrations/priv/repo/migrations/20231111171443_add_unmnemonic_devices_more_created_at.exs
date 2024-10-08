defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesMoreCreatedAt do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("books", prefix: "unmnemonic_devices") do
      add(:inserted_at, :utc_datetime, default: fragment("now()"))
    end

    alter table("destinations", prefix: "unmnemonic_devices") do
      add(:inserted_at, :utc_datetime, default: fragment("now()"))
    end
  end
end
