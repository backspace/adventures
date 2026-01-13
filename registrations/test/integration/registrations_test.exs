defmodule Registrations.Integration.ClandestineRendezvous.Registrations do
  @moduledoc false
  use RegistrationsWeb.FeatureCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "clandestine-rendezvous"

  alias Registrations.Pages.Account
  alias Registrations.Pages.Details
  alias Registrations.Pages.ForgotPassword
  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav
  alias Registrations.Pages.Register

  test "registering", %{session: session} do
    Registrations.WindowHelpers.set_window_to_show_account(session)

    visit(session, "/")
    Nav.register_link().click(session)

    Register.submit(session)

    assert Nav.error_text(session) ==
             "Oops, something went wrong! Please check the errors below:\nPassword can't be blank\nEmail can't be blank"

    assert Register.email_error(session) == "Email can't be blank"
    # FIXME fix plural detection
    assert Register.password_error(session) == "Password can't be blank"

    Register.fill_email(session, "franklin.w.dixon@example.com")
    Register.submit(session)

    assert Nav.error_text(session) ==
             "Oops, something went wrong! Please check the errors below:\nPassword can't be blank"

    Register.fill_email(session, "samuel.delaney@example.com")
    Register.fill_password(session, "nestofspiders")
    Register.fill_password_confirmation(session, "nestofspiders")
    Register.submit(session)

    assert Nav.info_text(session) == "Your account was created"

    [admin_email, welcome_email] = Registrations.SwooshHelper.sent_email()

    assert admin_email.to == [{"", "b@events.chromatin.ca"}]
    assert admin_email.from == {"", "b@events.chromatin.ca"}
    assert admin_email.subject == "samuel.delaney@example.com registered"

    assert welcome_email.to == [{"", "samuel.delaney@example.com"}]
    assert welcome_email.subject == "[rendezvous] Welcome!"
    assert String.contains?(welcome_email.text_body, "secret society")
    assert String.contains?(welcome_email.html_body, "secret society")

    assert Nav.logout_link().text(session) == "Log out samuel.delaney@example.com"

    assert Details.active?(session)
  end

  test "logging in", %{session: session} do
    insert(:octavia)

    Registrations.WindowHelpers.set_window_to_show_account(session)

    visit(session, "/")
    Nav.login_link().click(session)

    Login.fill_email(session, "Octavia.butler@example.com")
    Login.fill_password(session, "Parable of the Talents")
    Login.submit(session)

    assert Nav.error_text(session) ==
             "The provided login details did not work. Please verify your credentials, and try again."

    Login.fill_password(session, "Xenogenesis")
    Login.submit(session)

    assert Nav.info_text(session) == "Logged in"
    assert Nav.logout_link().text(session) == "Log out octavia.butler@example.com"

    assert Details.active?(session)

    Nav.logout_link().click(session)

    assert Nav.info_text(session) == "Logged out"
    assert Nav.login_link().present?(session)
    assert Nav.register_link().present?(session)
  end

  test "changing password", %{session: session} do
    insert(:octavia)

    Registrations.WindowHelpers.set_window_to_show_account(session)

    visit(session, "/")
    Login.login_as_admin(session)

    Nav.edit_details(session)
    Details.edit_account(session)

    Account.fill_current_password(session, "Wrong")
    Account.submit(session)

    assert Nav.error_text(session) ==
             "Oops, something went wrong! Please check the errors below:\nCurrent password is invalid"

    Account.fill_current_password(session, "Xenogenesis")
    Account.fill_new_password(session, "abcde")
    Account.fill_new_password_confirmation(session, "vwxyz")
    Account.submit(session)

    assert Nav.error_text(session) ==
             "Oops, something went wrong! Please check the errors below:\nPassword should be at least 8 character(s)\nPassword confirmation does not match confirmation"

    Account.fill_current_password(session, "Xenogenesis")
    Account.fill_new_password(session, "Lilith’s Brood")
    Account.fill_new_password_confirmation(session, "Lilith’s Brood")
    Account.submit(session)

    assert Nav.info_text(session) == "Your account has been updated."

    Nav.logout_link().click(session)

    visit(session, "/")
    Nav.login_link().click(session)

    Login.fill_email(session, "octavia.butler@example.com")
    Login.fill_password(session, "Xenogenesis")
    Login.submit(session)

    assert Nav.error_text(session) ==
             "The provided login details did not work. Please verify your credentials, and try again."

    Login.fill_password(session, "Lilith’s Brood")
    Login.submit(session)

    assert Nav.info_text(session) == "Logged in"
  end

  test "forgot password", %{session: session} do
    Registrations.WindowHelpers.set_window_to_show_account(session)

    insert(:octavia)

    visit(session, "/")

    Nav.login_link().click(session)
    Login.click_forgot_password(session)

    ForgotPassword.fill_email(session, "octavia.butler@example.com")
    ForgotPassword.submit(session)

    assert Nav.info_text(session) ==
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

    visit(session, "/reset-password/fake")
    assert Nav.error_text(session) == "The reset token has expired."

    visit(session, reset_path)

    Account.fill_new_password(session, "anewpassword")
    Account.fill_new_password_confirmation(session, "awrongpassword")
    Account.submit(session)

    assert Nav.error_text(session) ==
             "Oops, something went wrong! Please check the errors below:\nPassword confirmation does not match confirmation"

    Account.fill_new_password(session, "anewpassword")
    Account.fill_new_password_confirmation(session, "anewpassword")
    Account.submit(session)

    assert Nav.info_text(session) == "The password has been updated."

    Login.fill_email(session, "Octavia.butler@example.com")
    Login.fill_password(session, "anewpassword")
    Login.submit(session)

    assert Nav.logout_link().text(session) == "Log out octavia.butler@example.com"

    Nav.logout_link().click(session)

    Login.login_as(session, "octavia.butler@example.com", "anewpassword")
    assert Nav.logout_link().text(session) == "Log out octavia.butler@example.com"

    Nav.logout_link().click(session)

    visit(session, reset_path)
    assert Nav.error_text(session) == "The reset token has expired."
  end

  test "delete account", %{session: session} do
    insert(:octavia)

    visit(session, "/")
    Login.login_as_admin(session)

    Nav.edit_details(session)
    Details.delete_account(session)

    assert Nav.info_text(session) == "Your account has been deleted. Sorry to see you go!"

    [admin_email] = Registrations.SwooshHelper.sent_email()

    assert admin_email.to == [{"", "b@events.chromatin.ca"}]
    assert admin_email.from == {"", "b@events.chromatin.ca"}
    assert admin_email.subject == "octavia.butler@example.com deleted their account"
  end

  test "delete with login", %{session: session} do
    insert(:octavia)

    visit(session, "/delete")
    Login.fill_email(session, "octavia.butler@example.com")
    Login.fill_password(session, "Xenogenesis")
    Login.submit(session)

    assert Nav.info_text(session) == "Your account has been deleted. Sorry to see you go!"
  end

  test "when registration is closed, a warning is displayed on the registration and details routes",
       %{session: session} do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :registration_closed,
      true
    )

    visit(session, "/")

    Nav.register_link().click(session)

    assert Nav.error_text(session) ==
             "Registration is closed; however, you may continue and we will email you"

    insert(:octavia)
    Login.login_as_admin(session)

    assert Nav.error_text(session) ==
             "You may change your details but it’s too late to guarantee the changes can be integrated"
  end
end

defmodule Registrations.Integration.UnmnemonicDevices.Registrations do
  @moduledoc false
  use RegistrationsWeb.FeatureCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "unmnemonic-devices"

  alias Registrations.Pages.Nav
  alias Registrations.Pages.Register

  test "registering sends email from and to a different address", %{session: session} do
    Registrations.WindowHelpers.set_window_to_show_account(session)

    visit(session, "/")
    Nav.register_link().click(session)

    Register.fill_email(session, "samuel.delaney@example.com")
    Register.fill_password(session, "nestofspiders")
    Register.fill_password_confirmation(session, "nestofspiders")
    Register.submit(session)

    [admin_email, welcome_email] = Registrations.SwooshHelper.sent_email()

    assert admin_email.to == [{"", "knut@chromatin.ca"}]
    assert admin_email.from == {"", "knut@chromatin.ca"}
    assert admin_email.subject == "samuel.delaney@example.com registered"

    assert welcome_email.to == [{"", "samuel.delaney@example.com"}]
    assert welcome_email.from == {"", "knut@chromatin.ca"}
    assert welcome_email.subject == "[unmnemonic] Welcome!"
  end
end
