defmodule Registrations.UnmnemonicDevices.Integration.Home do
  @moduledoc false
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "unmnemonic-devices"
  use Hound.Helpers

  alias Registrations.Pages.Home
  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav

  require WaitForIt

  hound_session(Registrations.ChromeHeadlessHelper.additional_capabilities())

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

    refute Home.pi().present?()
  end

  test "pi shows when compromised but cannot create a voicepass when not logged in" do
    insert(:unmnemonic_devices_settings, compromised: true)

    navigate_to("/")

    assert Home.pi().present?()

    Home.pi().click()

    refute Home.overlay().regenerate().present?()
  end

  test "overlay shows voicepass when it exists" do
    insert(:unmnemonic_devices_settings, compromised: true)
    insert(:octavia, voicepass: "acknowledgements")

    Registrations.WindowHelpers.set_window_to_show_account()

    navigate_to("/")
    Nav.login_link().click()
    Login.fill_email("Octavia.butler@example.com")
    Login.fill_password("Xenogenesis")
    Login.submit()

    Home.pi().click()

    assert Home.overlay().voicepass().text() == "acknowledgements"
  end

  test "a logged-in user can generate a voicepass" do
    insert(:unmnemonic_devices_settings, compromised: true)
    insert(:octavia)

    Registrations.WindowHelpers.set_window_to_show_account()

    navigate_to("/")
    Nav.login_link().click()
    Login.fill_email("Octavia.butler@example.com")
    Login.fill_password("Xenogenesis")
    Login.submit()

    Home.pi().click()

    assert Home.overlay().voicepass().text() == "generate a voicepass"

    assert Home.overlay().regenerate().present?()
    assert Home.overlay().regenerate().text() == "generate"

    Home.overlay().regenerate().click()

    WaitForIt.wait(String.length(Home.overlay().voicepass().text()) == 16)

    new_voicepass = Home.overlay().voicepass().text()
    assert String.length(new_voicepass) == 16

    assert Home.overlay().regenerate().text() == "regenerate"

    refresh_page()
    Home.pi().click()
    assert Home.overlay().voicepass().text() == new_voicepass
  end
end

defmodule Registrations.Waydowntown.Integration.Home do
  @moduledoc false
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "waydowntown"
  use Hound.Helpers

  alias Registrations.Pages.Home
  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav

  hound_session(Registrations.ChromeHeadlessHelper.additional_capabilities())

  test "placeholder does not show by default" do
    navigate_to("/")

    refute(Home.placeholder_exists?())
  end

  test "placeholder shows when set in config, nav is hidden" do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    navigate_to("/")

    assert(Home.placeholder_exists?())
    refute(Nav.present?())
  end

  test "placeholder shows with a query parameter" do
    navigate_to("/?placeholder=true")

    assert(Home.placeholder_exists?())
  end

  test "placeholder can by bypassed with a query parameter" do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    navigate_to("/?placeholder=false")

    refute(Home.placeholder_exists?())
  end

  test "placeholder does not show when logged in" do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    insert(:octavia)

    Registrations.WindowHelpers.set_window_to_show_account()

    Login.visit()
    Login.fill_email("Octavia.butler@example.com")
    Login.fill_password("Xenogenesis")
    Login.submit()

    navigate_to("/")
    refute(Home.placeholder_exists?())
  end

  test "placeholder page has waitlist form" do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    navigate_to("/")

    assert Home.placeholder_exists?()

    Home.fill_waitlist_email("interested@example.com")
    Home.fill_waitlist_question("When will the event take place?")
    Home.submit_waitlist()

    assert Nav.info_text() == "we’ll let you know when registration opens"

    [sent_email] = Registrations.SwooshHelper.sent_email()
    assert sent_email.to == [{"", "b@events.chromatin.ca"}]
    assert sent_email.from == {"", "b@events.chromatin.ca"}

    assert sent_email.subject == "Waitlist submission from interested@example.com"

    assert sent_email.text_body ==
             "Email: interested@example.com\nQuestion: When will the event take place?"
  end

  test "placeholder page shows error for invalid email in waitlist form" do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    navigate_to("/")

    assert Home.placeholder_exists?()

    Home.fill_waitlist_email("not_an_email")
    Home.fill_waitlist_question("When will the event take place?")

    # This bypasses client-side validation
    execute_script("document.getElementById('waitlist_email').type = 'text';")

    Home.submit_waitlist()

    assert Nav.info_text() == "was that an email address?"

    assert Registrations.SwooshHelper.sent_email() == []
  end
end
