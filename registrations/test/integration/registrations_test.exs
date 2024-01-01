defmodule Registrations.Integration.ClandestineRendezvous.Registrations do
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.ResetRegistrationClosed
  use Registrations.ClandestineRendezvous

  alias Registrations.Pages.Register
  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav
  alias Registrations.Pages.Details
  alias Registrations.Pages.Account
  alias Registrations.Pages.ForgotPassword

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session()

  def set_window_to_show_account do
    set_window_size(current_window_handle(), 720, 450)
  end

  test "registering" do
    set_window_to_show_account()

    navigate_to("/")
    Nav.register_link().click

    Register.submit()
    assert Nav.error_text() == "Unable to create account"
    assert Register.email_error() == "Email can't be blank"
    # FIXME fix plural detection
    assert Register.password_error() == "Password can't be blank"

    Register.fill_email("franklin.w.dixon@example.com")
    Register.submit()
    assert Nav.error_text() == "Unable to create account"

    Register.fill_email("samuel.delaney@example.com")
    Register.fill_password("nestofspiders")
    Register.submit()

    assert Nav.info_text() == "Your account was created"

    [welcome_email, admin_email] = Registrations.SwooshHelper.sent_email()

    assert admin_email.to == [{"", "b@events.chromatin.ca"}]
    assert admin_email.from == {"", "b@events.chromatin.ca"}
    assert admin_email.subject == "samuel.delaney@example.com registered"

    assert welcome_email.to == [{"", "samuel.delaney@example.com"}]
    assert welcome_email.subject == "[rendezvous] Welcome!"
    assert String.contains?(welcome_email.text_body, "secret society")
    assert String.contains?(welcome_email.html_body, "secret society")

    assert Nav.logout_link().text == "Log out samuel.delaney@example.com"

    assert Details.active?()
  end

  test "logging in" do
    insert(:octavia)

    set_window_to_show_account()

    navigate_to("/")
    Nav.login_link().click

    Login.fill_email("Octavia.butler@example.com")
    Login.fill_password("Parable of the Talents")
    Login.submit()

    assert Nav.error_text() == "Wrong email or password"

    Login.fill_password("Xenogenesis")
    Login.submit()

    assert Nav.info_text() == "Logged in"
    assert Nav.logout_link().text == "Log out octavia.butler@example.com"

    assert Details.active?()

    Nav.logout_link().click

    assert Nav.info_text() == "Logged out"
    assert Nav.login_link().present?
    assert Nav.register_link().present?
  end

  test "changing password" do
    insert(:octavia)

    set_window_to_show_account()

    navigate_to("/")
    Login.login_as_admin()

    Nav.edit_details()
    Details.edit_account()

    Account.fill_current_password("Wrong")
    Account.submit()

    assert Nav.error_text() == "Please enter your current password"

    Account.fill_current_password("Xenogenesis")
    Account.fill_new_password("abcde")
    Account.fill_new_password_confirmation("vwxyz")
    Account.submit()

    assert Nav.error_text() == "New passwords must match"

    Account.fill_current_password("Xenogenesis")
    Account.fill_new_password("Lilith’s Brood")
    Account.fill_new_password_confirmation("Lilith’s Brood")
    Account.submit()

    assert Nav.info_text() == "Your password has been changed"

    Nav.logout_link().click

    navigate_to("/")
    Nav.login_link().click

    Login.fill_email("octavia.butler@example.com")
    Login.fill_password("Xenogenesis")
    Login.submit()

    assert Nav.error_text() == "Wrong email or password"

    Login.fill_password("Lilith’s Brood")
    Login.submit()

    assert Nav.info_text() == "Logged in"
  end

  test "forgot password" do
    set_window_to_show_account()

    insert(:octavia)

    navigate_to("/")

    Nav.login_link().click
    Login.click_forgot_password()

    ForgotPassword.fill_email("noone@example.com")
    ForgotPassword.submit()

    assert Nav.error_text() == "No registration with that email address found"
    refute Registrations.SwooshHelper.emails_sent?()

    ForgotPassword.fill_email("octavia.butler@example.com")
    ForgotPassword.submit()

    assert Nav.info_text() == "Check your email for a password reset link"

    [forgot_password_email] = Registrations.SwooshHelper.sent_email()

    assert forgot_password_email.to == [{"", "octavia.butler@example.com"}]
    assert forgot_password_email.from == {"", "b@events.chromatin.ca"}
    assert forgot_password_email.subject == "[rendezvous] Password reset"

    [url] =
      Floki.find(forgot_password_email.html_body, "a")
      |> Floki.attribute("href")

    reset_path = URI.parse(url).path

    assert String.starts_with?(reset_path, "/reset/%242b")

    navigate_to("/reset/fake")
    assert Nav.error_text() == "Unknown password reset token"

    navigate_to(reset_path)

    Account.fill_new_password("anewpassword")
    Account.fill_new_password_confirmation("awrongpassword")
    Account.submit()

    assert Nav.error_text() == "New passwords must match"

    Account.fill_new_password("anewpassword")
    Account.fill_new_password_confirmation("anewpassword")
    Account.submit()

    assert Nav.info_text() == "Your password has been changed"
    assert Nav.logout_link().text == "Log out octavia.butler@example.com"

    Nav.logout_link().click

    Login.login_as("octavia.butler@example.com", "anewpassword")
    assert Nav.logout_link().text == "Log out octavia.butler@example.com"

    navigate_to(reset_path)
    assert Nav.error_text() == "Unknown password reset token"
  end

  test "delete account" do
    insert(:octavia)

    navigate_to("/")
    Login.login_as_admin()

    Nav.edit_details()
    Details.delete_account()

    Account.fill_current_password("wrongpassword")
    Account.submit()

    assert Nav.error_text() == "Your password did not match"

    Account.fill_current_password("Xenogenesis")
    Account.submit()

    assert Nav.info_text() == "Your account has been deleted 😧"

    [admin_email] = Registrations.SwooshHelper.sent_email()

    assert admin_email.to == [{"", "b@events.chromatin.ca"}]
    assert admin_email.from == {"", "b@events.chromatin.ca"}
    assert admin_email.subject == "octavia.butler@example.com deleted their account"
  end

  test "when registration is closed, a warning is displayed on the registration and details routes" do
    Application.put_env(:registrations, :registration_closed, true)

    navigate_to("/")

    Nav.register_link().click

    assert Nav.error_text() ==
             "Registration is closed; however, you may continue and we will email you"

    insert(:octavia)
    Login.login_as_admin()

    assert Nav.error_text() ==
             "You may change your details but it’s too late to guarantee the changes can be integrated"
  end
end

defmodule Registrations.Integration.UnmnemonicDevices.Registrations do
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.ResetRegistrationClosed
  use Registrations.UnmnemonicDevices

  alias Registrations.Pages.Register
  alias Registrations.Pages.Nav

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session()

  def set_window_to_show_account do
    set_window_size(current_window_handle(), 720, 450)
  end

  test "registering sends email from and to a different address" do
    set_window_to_show_account()

    navigate_to("/")
    Nav.register_link().click

    Register.fill_email("samuel.delaney@example.com")
    Register.fill_password("nestofspiders")
    Register.submit()

    [welcome_email, admin_email] = Registrations.SwooshHelper.sent_email()

    assert admin_email.to == [{"", "knut@chromatin.ca"}]
    assert admin_email.from == {"", "knut@chromatin.ca"}
    assert admin_email.subject == "samuel.delaney@example.com registered"

    assert welcome_email.to == [{"", "samuel.delaney@example.com"}]
    assert welcome_email.from == {"", "knut@chromatin.ca"}
    assert welcome_email.subject == "[unmnemonic] Welcome!"
  end
end
