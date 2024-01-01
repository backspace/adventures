defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesSchema do
  use Ecto.Migration

  def up do
    execute("CREATE SCHEMA unmnemonic_devices")
  end

  def down do
    execute("DROP SCHEMA unmnemonic_devices")
  end
end
