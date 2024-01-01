defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesDestinationAnswer do
  use Ecto.Migration

  def change do
    alter table("destinations", prefix: "unmnemonic_devices") do
      add(:answer, :string)
    end
  end
end
