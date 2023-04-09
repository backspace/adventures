defmodule AdventureRegistrationsWeb.UnmnemonicDevices.Settings do
  use AdventureRegistrationsWeb, :model

  @schema_prefix "unmnemonic_devices"

  schema "settings" do
    field :compromised, :boolean

    timestamps()
  end
end
