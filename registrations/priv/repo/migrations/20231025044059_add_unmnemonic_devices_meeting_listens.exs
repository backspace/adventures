defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesMeetingListens do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("meetings", prefix: "unmnemonic_devices") do
      add(:listens, :integer, default: 0)
    end
  end
end
