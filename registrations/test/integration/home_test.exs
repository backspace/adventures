defmodule Registrations.UnmnemonicDevices.Integration.Home do
  @moduledoc false
  use RegistrationsWeb.FeatureCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "unmnemonic-devices"

  alias Registrations.Pages.Home
  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav
  alias Wallaby.Element
  alias Wallaby.Query

  require WaitForIt

  test "head tags are correct", %{session: session} do
    visit(session, "/")

    assert page_title(session) == "unmnemonic devices"

    assert Element.attr(
             find(session, Query.css("meta[property='og:title']", visible: false)),
             "content"
           ) ==
             "unmnemonic devices: Zagreb, June 8"

    assert Element.attr(
             find(session, Query.css("meta[property='og:url']", visible: false)),
             "content"
           ) ==
             "http://example.com"

    assert Element.attr(
             find(session, Query.css("meta[property='og:image']", visible: false)),
             "content"
           ) ==
             "http://example.com/images/unmnemonic-devices/meta.png"
  end

  test "pi does not show by default", %{session: session} do
    insert(:unmnemonic_devices_settings)

    visit(session, "/")

    refute Home.pi().present?(session)
  end

  test "pi shows when compromised but cannot create a voicepass when not logged in", %{
    session: session
  } do
    insert(:unmnemonic_devices_settings, compromised: true)

    visit(session, "/")

    assert Home.pi().present?(session)

    Home.pi().click(session)

    refute Home.overlay().regenerate().present?(session)
  end

  test "overlay shows voicepass when it exists", %{session: session} do
    insert(:unmnemonic_devices_settings, compromised: true)
    insert(:octavia, voicepass: "acknowledgements")

    Registrations.WindowHelpers.set_window_to_show_account(session)

    visit(session, "/")
    Nav.login_link().click(session)
    Login.fill_email(session, "Octavia.butler@example.com")
    Login.fill_password(session, "Xenogenesis")
    Login.submit(session)

    Home.pi().click(session)

    assert Home.overlay().voicepass().text(session) == "acknowledgements"
  end

  test "a logged-in user can generate a voicepass", %{session: session} do
    insert(:unmnemonic_devices_settings, compromised: true)
    insert(:octavia)

    Registrations.WindowHelpers.set_window_to_show_account(session)

    visit(session, "/")
    Nav.login_link().click(session)
    Login.fill_email(session, "Octavia.butler@example.com")
    Login.fill_password(session, "Xenogenesis")
    Login.submit(session)

    Home.pi().click(session)

    assert Home.overlay().voicepass().text(session) == "generate a voicepass"

    assert Home.overlay().regenerate().present?(session)
    assert Home.overlay().regenerate().text(session) == "generate"

    Home.overlay().regenerate().click(session)

    WaitForIt.wait(String.length(Home.overlay().voicepass().text(session)) == 16)

    new_voicepass = Home.overlay().voicepass().text(session)
    assert String.length(new_voicepass) == 16

    assert Home.overlay().regenerate().text(session) == "regenerate"

    visit(session, "/")
    Home.pi().click(session)
    assert Home.overlay().voicepass().text(session) == new_voicepass
  end
end

defmodule Registrations.Waydowntown.Integration.Home do
  @moduledoc false
  use RegistrationsWeb.FeatureCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "waydowntown"

  alias Registrations.Pages.Home
  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav

  test "placeholder does not show by default", %{session: session} do
    visit(session, "/")

    refute(Home.placeholder_exists?(session))
  end

  test "placeholder shows when set in config, nav is hidden", %{session: session} do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    visit(session, "/")

    assert(Home.placeholder_exists?(session))
    refute(Nav.present?(session))
  end

  test "placeholder shows with a query parameter", %{session: session} do
    visit(session, "/?placeholder=true")

    assert(Home.placeholder_exists?(session))
  end

  test "placeholder can by bypassed with a query parameter", %{session: session} do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    visit(session, "/?placeholder=false")

    refute(Home.placeholder_exists?(session))
  end

  test "placeholder does not show when logged in", %{session: session} do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    insert(:octavia)

    Registrations.WindowHelpers.set_window_to_show_account(session)

    Login.visit(session)
    Login.fill_email(session, "Octavia.butler@example.com")
    Login.fill_password(session, "Xenogenesis")
    Login.submit(session)

    visit(session, "/")
    refute(Home.placeholder_exists?(session))
  end

  test "placeholder page has waitlist form", %{session: session} do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    visit(session, "/")

    assert Home.placeholder_exists?(session)

    Home.fill_waitlist_email(session, "interested@example.com")
    Home.fill_waitlist_question(session, "When will the event take place?")
    Home.submit_waitlist(session)

    assert Nav.info_text(session) == "we’ll let you know when registration opens"

    [sent_email] = Registrations.SwooshHelper.sent_email()
    assert sent_email.to == [{"", "mdrysdale@waydown.town"}]
    assert sent_email.from == {"", "mdrysdale@waydown.town"}

    assert sent_email.subject == "Waitlist submission from interested@example.com"

    assert sent_email.text_body ==
             "Email: interested@example.com\nQuestion: When will the event take place?"
  end

  test "placeholder page does not have waitlist form when hidden", %{session: session} do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :hide_waitlist,
      true
    )

    visit(session, "/")

    refute Home.placeholder_exists?(session)
  end

  test "placeholder page shows error for invalid email in waitlist form", %{session: session} do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    visit(session, "/")

    assert Home.placeholder_exists?(session)

    Home.fill_waitlist_email(session, "not_an_email")
    Home.fill_waitlist_question(session, "When will the event take place?")

    # This bypasses client-side validation
    execute_script(session, "document.getElementById('waitlist_email').type = 'text';")

    Home.submit_waitlist(session)

    assert Nav.info_text(session) == "was that an email address?"

    assert Registrations.SwooshHelper.sent_email() == []
  end

  test "placeholder page doesn't send email when spam is detected in email", %{
    session: session
  } do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :spam_strings,
      ["spam", "unwanted"]
    )

    visit(session, "/")

    assert Home.placeholder_exists?(session)

    Home.fill_waitlist_email(session, "spam@example.com")
    Home.fill_waitlist_question(session, "When will the event take place?")
    Home.submit_waitlist(session)

    assert Nav.info_text(session) == "we’ll let you know when registration opens"

    assert Registrations.SwooshHelper.sent_email() == []
  end

  test "placeholder page doesn't send email when spam is detected in question", %{
    session: session
  } do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :placeholder,
      true
    )

    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :spam_strings,
      ["spam", "unwanted"]
    )

    visit(session, "/")

    assert Home.placeholder_exists?(session)

    Home.fill_waitlist_email(session, "interested@example.com")
    Home.fill_waitlist_question(session, "When will this unwanted event take place?")
    Home.submit_waitlist(session)

    assert Nav.info_text(session) == "we’ll let you know when registration opens"

    assert Registrations.SwooshHelper.sent_email() == []
  end
end
