defmodule Cr2016site.Integration.Registrations do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper

  alias Cr2016site.Pages.Register
  alias Cr2016site.Pages.Login
  alias Cr2016site.Pages.Nav
  alias Cr2016site.Pages.Details

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session

  test "registering" do
    set_window_size current_window_handle, 720, 450

    navigate_to "/"
    Nav.register_link.click

    Register.submit
    assert Nav.alert_text == "Unable to create account"
    assert Register.email_error == "Email has invalid format"
    assert Register.password_error == "Password should be at least 5 characters"

    Register.fill_email "franklin.w.dixon@example.com"
    Register.submit
    assert Nav.alert_text == "Unable to create account"

    Register.fill_email "samuel.delaney@example.com"
    Register.fill_password "nestofspiders"
    Register.submit

    assert Nav.alert_text == "Your account was created"

    sent_email = Cr2016site.MailgunHelper.sent_email
    assert sent_email["to"] == "samuel.delaney@example.com"
    assert sent_email["subject"] == "Welcome!"

    assert Nav.logout_link.text == "Log out samuel.delaney@example.com"

    assert Details.active?
  end

  test "logging in" do
    # FIXME save a user with automatic encryption of password?
    Forge.saved_user email: "octavia.butler@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Xenogenesis")

    set_window_size current_window_handle, 720, 450

    navigate_to "/"
    Nav.login_link.click

    Login.fill_email "octavia.butler@example.com"
    Login.fill_password "Parable of the Talents"
    Login.submit

    assert Nav.alert_text == "Wrong email or password"

    Login.fill_password "Xenogenesis"
    Login.submit

    assert Nav.alert_text == "Logged in"
    assert Nav.logout_link.text == "Log out octavia.butler@example.com"

    assert Details.active?

    Nav.logout_link.click

    assert Nav.alert_text == "Logged out"
    assert Nav.login_link.present?
    assert Nav.register_link.present?
  end
end
