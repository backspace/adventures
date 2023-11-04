defmodule AdventureRegistrationsWeb.UnmnemonicDevices.Settings do
  use AdventureRegistrationsWeb, :model

  @schema_prefix "unmnemonic_devices"

  schema "settings" do
    field(:begun, :boolean, default: false)
    field(:compromised, :boolean, default: false)
    field(:down, :boolean, default: false)
    field(:ending, :boolean, default: false)
    field(:override, :string)
    field(:vrs_href, :string)
    field(:vrs_human, :string)

    timestamps()
  end

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:override, :begun, :compromised, :ending, :down, :vrs_href, :vrs_human])
  end
end
