defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesCallsPaths do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("calls", prefix: "unmnemonic_devices") do
      add(:path, :string)
    end
  end
end
