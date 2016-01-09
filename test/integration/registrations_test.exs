defmodule Cr2016site.Integration.Registrations do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper

  alias Cr2016site.Pages.Register
  alias Cr2016site.Pages.Login
  alias Cr2016site.Pages.Nav
  alias Cr2016site.Pages.Details
  alias Cr2016site.Pages.Account
  alias Cr2016site.Pages.ForgotPassword

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session

  def set_window_to_show_account do
    set_window_size current_window_handle, 720, 450
  end

  test "registering" do
    set_window_to_show_account

    navigate_to "/"
    Nav.register_link.click

    Register.submit
    assert Nav.error_text == "Unable to create account"
    assert Register.email_error == "Email has invalid format"
    # FIXME fix plural detection
    assert Register.password_error == "Password should be at least 5 character(s)"

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

    set_window_to_show_account

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

    set_window_to_show_account

    navigate_to "/"
    Login.login_as "octavia.butler@example.com", "Xenogenesis"

    Nav.edit_details
    Details.edit_account

    Account.fill_current_password "Wrong"
    Account.submit

    assert Nav.error_text == "Please enter your current password"

    Account.fill_current_password "Xenogenesis"
    Account.fill_new_password "abcde"
    Account.fill_new_password_confirmation "vwxyz"
    Account.submit

    assert Nav.error_text == "New passwords must match"

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

  test "forgot password" do
    set_window_to_show_account

    Forge.saved_user email: "octavia.butler@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Xenogenesis")

    navigate_to "/"

    Nav.login_link.click
    Login.click_forgot_password

    ForgotPassword.fill_email "noone"
    ForgotPassword.submit

    assert Nav.error_text == "No registration with that email address found"
    refute Cr2016site.MailgunHelper.emails_sent?

    ForgotPassword.fill_email "octavia.butler@example.com"
    ForgotPassword.submit

    assert Nav.info_text == "Check your email for a password reset link"

    [forgot_password_email] = Cr2016site.MailgunHelper.sent_email

    assert forgot_password_email["to"] == "octavia.butler@example.com"
    assert forgot_password_email["from"] == "b@events.chromatin.ca"
    assert forgot_password_email["subject"] == "[rendezvous] Password reset"

    [url] = Floki.find(forgot_password_email["html"], "a")
    |> Floki.attribute("href")

    reset_path = URI.parse(url).path

    assert String.starts_with?(reset_path, "/reset/%242b")

    navigate_to "/reset/fake"
    assert Nav.error_text == "Unknown password reset token"

    navigate_to reset_path

    Account.fill_new_password "anewpassword"
    Account.fill_new_password_confirmation "awrongpassword"
    Account.submit

    assert Nav.error_text == "New passwords must match"

    Account.fill_new_password "anewpassword"
    Account.fill_new_password_confirmation "anewpassword"
    Account.submit

    assert Nav.info_text == "Your password has been changed"
    assert Nav.logout_link.text == "Log out octavia.butler@example.com"

    Nav.logout_link.click

    Login.login_as "octavia.butler@example.com", "anewpassword"
    assert Nav.logout_link.text == "Log out octavia.butler@example.com"

    navigate_to reset_path
    assert Nav.error_text == "Unknown password reset token"
  end
end
