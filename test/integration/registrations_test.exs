defmodule Cr2016site.Integration.Registrations do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper

  alias Cr2016site.Pages.Register
  alias Cr2016site.Pages.Login
  alias Cr2016site.Pages.Nav
  alias Cr2016site.Pages.Details
  alias Cr2016site.Pages.Account

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session

  test "registering" do
    set_window_size current_window_handle, 720, 450

    navigate_to "/"
    Nav.register_link.click

    Register.submit
    assert Nav.error_text == "Unable to create account"
    assert Register.email_error == "Email has invalid format"
    assert Register.password_error == "Password should be at least 5 characters"

    Register.fill_email "franklin.w.dixon@example.com"
    Register.submit
    assert Nav.error_text == "Unable to create account"

    Register.fill_email "samuel.delaney@example.com"
    Register.fill_password "nestofspiders"
    Register.submit

    assert Nav.info_text == "Your account was created"

    [admin_email, welcome_email] = Cr2016site.MailgunHelper.sent_email

    assert admin_email["to"] == "b@events.chromatin.ca"
    assert admin_email["from"] == "b@events.chromatin.ca"
    assert admin_email["subject"] == "samuel.delaney@example.com registered"

    assert welcome_email["to"] == "samuel.delaney@example.com"
    assert welcome_email["subject"] == "Welcome!"

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

    assert Nav.error_text == "Wrong email or password"

    Login.fill_password "Xenogenesis"
    Login.submit

    assert Nav.info_text == "Logged in"
    assert Nav.logout_link.text == "Log out octavia.butler@example.com"

    assert Details.active?

    Nav.logout_link.click

    assert Nav.info_text == "Logged out"
    assert Nav.login_link.present?
    assert Nav.register_link.present?
  end

  test "changing password" do
    Forge.saved_user email: "octavia.butler@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Xenogenesis")

    set_window_size current_window_handle, 720, 450

    navigate_to "/"
    Login.login_as "octavia.butler@example.com", "Xenogenesis"

    Nav.edit_details
    Details.edit_account

    Account.fill_current_password "Wrong"
    Account.submit

    assert Nav.error_text == "Please enter your current password"

    Account.fill_current_password "Xenogenesis"
    Account.fill_new_password "Lilith’s Brood"
    Account.fill_new_password_confirmation "Lilith’s Brood"
    Account.submit

    assert Nav.info_text == "Your password has been changed"

    Nav.logout_link.click

    navigate_to "/"
    Nav.login_link.click

    Login.fill_email "octavia.butler@example.com"
    Login.fill_password "Xenogenesis"
    Login.submit

    assert Nav.error_text == "Wrong email or password"

    Login.fill_password "Lilith’s Brood"
    Login.submit

    assert Nav.info_text == "Logged in"
  end
end
