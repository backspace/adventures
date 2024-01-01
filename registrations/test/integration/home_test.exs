defmodule Registrations.UnmnemonicDevices.Integration.Home do
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.UnmnemonicDevices

  alias Registrations.Pages.Home
  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav

  use Hound.Helpers

  require WaitForIt

  def set_window_to_show_account do
    set_window_size(current_window_handle(), 720, 450)
  end

  hound_session()

  test "head tags are correct" do
    navigate_to("/")

    assert inner_text({:css, "title"}) == "unmnemonic devices"

    assert attribute_value({:css, "meta[property='og:title']"}, "content") ==
             "unmnemonic devices: Zagreb, June 8"

    assert attribute_value({:css, "meta[property='og:url']"}, "content") == "http://example.com"

    assert attribute_value({:css, "meta[property='og:image']"}, "content") ==
             "http://example.com/images/unmnemonic-devices/meta.png"
  end

  test "pi does not show by default" do
    insert(:unmnemonic_devices_settings)

    navigate_to("/")

    refute Home.pi().present?
  end

  test "pi shows when compromised but cannot create a voicepass when not logged in" do
    insert(:unmnemonic_devices_settings, compromised: true)

    navigate_to("/")

    assert Home.pi().present?

    Home.pi().click

    refute Home.overlay().regenerate.present?
  end

  test "overlay shows voicepass when it exists" do
    insert(:unmnemonic_devices_settings, compromised: true)
    insert(:octavia, voicepass: "acknowledgements")

    set_window_to_show_account()

    navigate_to("/")
    Nav.login_link().click
    Login.fill_email("Octavia.butler@example.com")
    Login.fill_password("Xenogenesis")
    Login.submit()

    Home.pi().click

    assert Home.overlay().voicepass.text == "acknowledgements"
  end

  test "a logged-in user can generate a voicepass" do
    insert(:unmnemonic_devices_settings, compromised: true)
    insert(:octavia)

    set_window_to_show_account()

    navigate_to("/")
    Nav.login_link().click
    Login.fill_email("Octavia.butler@example.com")
    Login.fill_password("Xenogenesis")
    Login.submit()

    Home.pi().click

    assert Home.overlay().voicepass.text == "generate a voicepass"

    assert Home.overlay().regenerate.present?
    assert Home.overlay().regenerate.text == "generate"

    Home.overlay().regenerate.click

    WaitForIt.wait(String.length(Home.overlay().voicepass.text) == 16)

    new_voicepass = Home.overlay().voicepass.text
    assert String.length(new_voicepass) == 16

    assert Home.overlay().regenerate.text == "regenerate"

    refresh_page()
    Home.pi().click
    assert Home.overlay().voicepass.text == new_voicepass
  end
end
