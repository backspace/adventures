defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesSettingsVrs do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("settings", prefix: "unmnemonic_devices") do
      add(:vrs_href, :string)
      add(:vrs_human, :string)
    end
  end
end
