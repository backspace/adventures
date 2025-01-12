defmodule Registrations.Integration.ClandestineRendezvous.Registrations do
  @moduledoc false
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "clandestine-rendezvous"
  use Hound.Helpers

  alias Registrations.Pages.Account
  alias Registrations.Pages.Details
  alias Registrations.Pages.ForgotPassword
  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav
  alias Registrations.Pages.Register

  # Import Hound helpers

  # Start a Hound session
  hound_session(Registrations.ChromeHeadlessHelper.additional_capabilities())

  test "registering" do
    Registrations.WindowHelpers.set_window_to_show_account()

    navigate_to("/")
    Nav.register_link().click()

    Register.submit()

    assert Nav.error_text() ==
             "Oops, something went wrong! Please check the errors below:\nPassword can't be blank\nEmail can't be blank"

    assert Register.email_error() == "Email can't be blank"
    # FIXME fix plural detection
    assert Register.password_error() == "Password can't be blank"

    Register.fill_email("franklin.w.dixon@example.com")
    Register.submit()

    assert Nav.error_text() ==
             "Oops, something went wrong! Please check the errors below:\nPassword can't be blank"

    Register.fill_email("samuel.delaney@example.com")
    Register.fill_password("nestofspiders")
    Register.fill_password_confirmation("nestofspiders")
    Register.submit()

    assert Nav.info_text() == "Your account was created"

    [admin_email, welcome_email] = Registrations.SwooshHelper.sent_email()

    assert admin_email.to == [{"", "b@events.chromatin.ca"}]
    assert admin_email.from == {"", "b@events.chromatin.ca"}
    assert admin_email.subject == "samuel.delaney@example.com registered"

    assert welcome_email.to == [{"", "samuel.delaney@example.com"}]
    assert welcome_email.subject == "[rendezvous] Welcome!"
    assert String.contains?(welcome_email.text_body, "secret society")
    assert String.contains?(welcome_email.html_body, "secret society")

    assert Nav.logout_link().text() == "Log out samuel.delaney@example.com"

    assert Details.active?()
  end

  test "logging in" do
    insert(:octavia)

    Registrations.WindowHelpers.set_window_to_show_account()

    navigate_to("/")
    Nav.login_link().click()

    Login.fill_email("Octavia.butler@example.com")
    Login.fill_password("Parable of the Talents")
    Login.submit()

    assert Nav.error_text() ==
             "The provided login details did not work. Please verify your credentials, and try again."

    Login.fill_password("Xenogenesis")
    Login.submit()

    assert Nav.info_text() == "Logged in"
    assert Nav.logout_link().text() == "Log out octavia.butler@example.com"

    assert Details.active?()

    Nav.logout_link().click()

    assert Nav.info_text() == "Logged out"
    assert Nav.login_link().present?()
    assert Nav.register_link().present?()
  end

  test "changing password" do
    insert(:octavia)

    Registrations.WindowHelpers.set_window_to_show_account()

    navigate_to("/")
    Login.login_as_admin()

    Nav.edit_details()
    Details.edit_account()

    Account.fill_current_password("Wrong")
    Account.submit()

    assert Nav.error_text() ==
             "Oops, something went wrong! Please check the errors below:\nCurrent password is invalid"

    Account.fill_current_password("Xenogenesis")
    Account.fill_new_password("abcde")
    Account.fill_new_password_confirmation("vwxyz")
    Account.submit()

    assert Nav.error_text() ==
             "Oops, something went wrong! Please check the errors below:\nPassword should be at least 8 character(s)\nPassword confirmation does not match confirmation"

    Account.fill_current_password("Xenogenesis")
    Account.fill_new_password("Lilith’s Brood")
    Account.fill_new_password_confirmation("Lilith’s Brood")
    Account.submit()

    assert Nav.info_text() == "Your account has been updated."

    Nav.logout_link().click()

    navigate_to("/")
    Nav.login_link().click()

    Login.fill_email("octavia.butler@example.com")
    Login.fill_password("Xenogenesis")
    Login.submit()

    assert Nav.error_text() ==
             "The provided login details did not work. Please verify your credentials, and try again."

    Login.fill_password("Lilith’s Brood")
    Login.submit()

    assert Nav.info_text() == "Logged in"
  end

  test "forgot password" do
    Registrations.WindowHelpers.set_window_to_show_account()

    insert(:octavia)

    navigate_to("/")

    Nav.login_link().click()
    Login.click_forgot_password()

    ForgotPassword.fill_email("octavia.butler@example.com")
    ForgotPassword.submit()

    assert Nav.info_text() ==
             "If an account for the provided email exists, an email with reset instructions will be sent to you. Please check your inbox."

    [forgot_password_email] = Registrations.SwooshHelper.sent_email()

    assert forgot_password_email.to == [{"", "octavia.butler@example.com"}]
    assert forgot_password_email.from == {"", "b@events.chromatin.ca"}
    assert forgot_password_email.subject == "[rendezvous] Reset password link"

    [url] =
      forgot_password_email.html_body
      |> Floki.find("a")
      |> Floki.attribute("href")

    reset_path = URI.parse(url).path

    assert String.starts_with?(reset_path, "/reset-password/")

    navigate_to("/reset-password/fake")
    assert Nav.error_text() == "The reset token has expired."

    navigate_to(reset_path)

    Account.fill_new_password("anewpassword")
    Account.fill_new_password_confirmation("awrongpassword")
    Account.submit()

    assert Nav.error_text() ==
             "Oops, something went wrong! Please check the errors below:\nPassword confirmation does not match confirmation"

    Account.fill_new_password("anewpassword")
    Account.fill_new_password_confirmation("anewpassword")
    Account.submit()

    assert Nav.info_text() == "The password has been updated."

    Login.fill_email("Octavia.butler@example.com")
    Login.fill_password("anewpassword")
    Login.submit()

    assert Nav.logout_link().text() == "Log out octavia.butler@example.com"

    Nav.logout_link().click()

    Login.login_as("octavia.butler@example.com", "anewpassword")
    assert Nav.logout_link().text() == "Log out octavia.butler@example.com"

    Nav.logout_link().click()

    navigate_to(reset_path)
    assert Nav.error_text() == "The reset token has expired."
  end

  test "delete account" do
    insert(:octavia)

    navigate_to("/")
    Login.login_as_admin()

    Nav.edit_details()
    Details.delete_account()

    assert Nav.info_text() == "Your account has been deleted. Sorry to see you go!"

    [admin_email] = Registrations.SwooshHelper.sent_email()

    assert admin_email.to == [{"", "b@events.chromatin.ca"}]
    assert admin_email.from == {"", "b@events.chromatin.ca"}
    assert admin_email.subject == "octavia.butler@example.com deleted their account"
  end

  test "delete with login" do
    insert(:octavia)

    navigate_to("/delete")
    Login.fill_email("octavia.butler@example.com")
    Login.fill_password("Xenogenesis")
    Login.submit()

    assert Nav.info_text() == "Your account has been deleted. Sorry to see you go!"
  end

  test "when registration is closed, a warning is displayed on the registration and details routes" do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :registration_closed,
      true
    )

    navigate_to("/")

    Nav.register_link().click()

    assert Nav.error_text() ==
             "Registration is closed; however, you may continue and we will email you"

    insert(:octavia)
    Login.login_as_admin()

    assert Nav.error_text() ==
             "You may change your details but it’s too late to guarantee the changes can be integrated"
  end
end

defmodule Registrations.Integration.UnmnemonicDevices.Registrations do
  @moduledoc false
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "unmnemonic-devices"
  use Hound.Helpers

  alias Registrations.Pages.Nav
  alias Registrations.Pages.Register

  # Import Hound helpers

  # Start a Hound session
  hound_session(Registrations.ChromeHeadlessHelper.additional_capabilities())

  test "registering sends email from and to a different address" do
    Registrations.WindowHelpers.set_window_to_show_account()

    navigate_to("/")
    Nav.register_link().click()

    Register.fill_email("samuel.delaney@example.com")
    Register.fill_password("nestofspiders")
    Register.fill_password_confirmation("nestofspiders")
    Register.submit()

    [admin_email, welcome_email] = Registrations.SwooshHelper.sent_email()

    assert admin_email.to == [{"", "knut@chromatin.ca"}]
    assert admin_email.from == {"", "knut@chromatin.ca"}
    assert admin_email.subject == "samuel.delaney@example.com registered"

    assert welcome_email.to == [{"", "samuel.delaney@example.com"}]
    assert welcome_email.from == {"", "knut@chromatin.ca"}
    assert welcome_email.subject == "[unmnemonic] Welcome!"
  end
end
