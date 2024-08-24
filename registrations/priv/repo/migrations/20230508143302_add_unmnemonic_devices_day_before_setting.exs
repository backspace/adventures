defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesDayBeforeSetting do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("settings", prefix: "unmnemonic_devices") do
      add(:day_before, :boolean, default: false)
      add(:degrading, :boolean, default: false)
    end
  end
end
