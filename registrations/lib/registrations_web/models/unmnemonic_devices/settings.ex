defmodule RegistrationsWeb.UnmnemonicDevices.Settings do
  @moduledoc false
  use RegistrationsWeb, :model

  @schema_prefix "unmnemonic_devices"

  schema "settings" do
    field(:begun, :boolean, default: false)
    field(:compromised, :boolean, default: false)
    field(:ending, :boolean, default: false)
    field(:notify_supervisor, :boolean, default: true)
    field(:override, :string)
    field(:vrs_href, :string)
    field(:vrs_human, :string)

    timestamps()
  end

  def changeset(settings, attrs) do
    cast(settings, attrs, [:override, :begun, :compromised, :ending, :notify_supervisor, :vrs_href, :vrs_human])
  end
end
