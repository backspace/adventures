defmodule Cr2016site.IntegrationTest do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper

  alias Cr2016site.RegisterPage
  alias Cr2016site.LoginPage
  alias Cr2016site.Nav

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session

  test "registering" do
    navigate_to "/"
    Nav.register_link.click

    RegisterPage.submit
    assert Nav.alert_text == "Unable to create account"
    assert RegisterPage.email_error == "Email has invalid format"
    assert RegisterPage.password_error == "Password should be at least 5 characters"

    RegisterPage.fill_email "franklin.w.dixon@example.com"
    RegisterPage.submit
    assert Nav.alert_text == "Unable to create account"

    RegisterPage.fill_email "samuel.delaney@example.com"
    RegisterPage.fill_password "nestofspiders"
    RegisterPage.submit

    assert Nav.alert_text == "Your account was created"

    sent_email = Cr2016site.MailgunHelper.sent_email
    assert sent_email["to"] == "samuel.delaney@example.com"
    assert sent_email["subject"] == "Welcome!"

    assert Nav.logout_link.text == "Log out samuel.delaney@example.com"
  end

  test "logging in" do
    # FIXME save a user with automatic encryption of password?
    Forge.saved_user email: "octavia.butler@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Xenogenesis")

    navigate_to "/"
    Nav.login_link.click

    LoginPage.fill_email "octavia.butler@example.com"
    LoginPage.fill_password "Parable of the Talents"
    LoginPage.submit

    assert Nav.alert_text == "Wrong email or password"

    LoginPage.fill_password "Xenogenesis"
    LoginPage.submit

    assert Nav.alert_text == "Logged in"
    assert Nav.logout_link.text == "Log out octavia.butler@example.com"

    Nav.logout_link.click

    assert Nav.alert_text == "Logged out"
    assert Nav.login_link.present?
    assert Nav.register_link.present?
  end

  test "logging in as an admin" do
    Forge.saved_user email: "francine.pascal@example.com"
    Forge.saved_user email: "octavia.butler@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Xenogenesis"), admin: true

    navigate_to "/"

    Nav.login_link.click

    LoginPage.fill_email "octavia.butler@example.com"
    LoginPage.fill_password "Xenogenesis"
    LoginPage.submit

    Nav.users_link.click
    assert page_source =~ "francine.pascal@example.com"
  end

  test "non-admins cannot access the user list" do
    Forge.saved_user email: "francine.pascal@example.com"

    navigate_to "/users"

    refute page_source =~ "francine.pascal@example.com"
  end
end

defmodule Cr2016site.Nav do
  use Hound.Helpers

  def alert_text do
    visible_text({:css, ".alert-info"})
  end

  def register_link do
    Cr2016site.Nav.RegisterLink
  end

  def login_link do
    Cr2016site.Nav.LoginLink
  end

  # FIXME there is surely a better way to do this?
  # macros/DSL to create page objects?
  def logout_link do
    Cr2016site.Nav.LogoutLink
  end

  def users_link do
    # This is me being lazy
    %{:click => click({:css, "a.users"})}
  end

  defmodule LogoutLink do
    @selector {:css, "a.logout"}

    def text do
      visible_text(@selector)
    end

    def click do
      click(@selector)
    end
  end

  defmodule LoginLink do
    @selector {:css, "a.login"}

    def click do
      click @selector
    end

    def present? do
      # Is this reasonable?
      apply(Hound.Helpers.Page, :find_element, Tuple.to_list(@selector))
    end
  end

  defmodule RegisterLink do
    @selector {:css, "a.register"}

    def click do
      click @selector
    end

    def present? do
      apply(Hound.Helpers.Page, :find_element, Tuple.to_list(@selector))
    end
  end
end

defmodule Cr2016site.RegisterPage do
  use Hound.Helpers

  def fill_email(email) do
    fill_field({:id, "email"}, email)
  end

  def email_error do
    visible_text({:css, ".errors .email"})
  end

  def fill_password(password) do
    fill_field({:id, "password"}, password)
  end

  def password_error do
    visible_text({:css, ".errors .password"})
  end

  def submit do
    click({:class, "btn"})
  end
end

defmodule Cr2016site.LoginPage do
  use Hound.Helpers

  def fill_email(email) do
    fill_field({:id, "email"}, email)
  end

  def fill_password(password) do
    fill_field({:id, "password"}, password)
  end

  def submit do
    click({:class, "btn"})
  end
end
