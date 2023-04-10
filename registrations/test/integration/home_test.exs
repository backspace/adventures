
defmodule AdventureRegistrations.UnmnemonicDevices.Integration.Home do
  use AdventureRegistrationsWeb.ConnCase
  use AdventureRegistrations.SwooshHelper
  use AdventureRegistrations.UnmnemonicDevices

  alias AdventureRegistrations.Pages.Home

  use Hound.Helpers

  hound_session()

  test "pi does not show by default" do
    insert(:unmnemonic_devices_settings)

    navigate_to("/")

    refute Home.pi_present?
  end

  test "pi shows when compromised" do
    insert(:unmnemonic_devices_settings, compromised: true)

    navigate_to("/")

    assert Home.pi_present?
  end
end
