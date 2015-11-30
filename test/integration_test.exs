defmodule Cr2016site.IntegrationTest do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper

  alias Cr2016site.RegisterPage
  alias Cr2016site.Nav

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session

  test "registering" do
    navigate_to "/"
    click({:link_text, "Register"})

    click({:class, "btn"})
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

    assert visible_text({:css, "a.logout"}) == "Log out samuel.delaney@example.com"
  end

  test "logging in" do
    # FIXME save a user with automatic encryption of password?
    Forge.saved_user email: "octavia.butler@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Xenogenesis")

    navigate_to "/"
    click({:link_text, "Log in"})

    fill_field({:id, "email"}, "octavia.butler@example.com")
    fill_field({:id, "password"}, "Parable of the Talents")
    click({:class, "btn"})

    assert visible_text({:css, ".alert-info"}) == "Wrong email or password"

    fill_field({:id, "password"}, "Xenogenesis")
    click({:class, "btn"})

    assert visible_text({:css, ".alert-info"}) == "Logged in"
    assert visible_text({:css, "a.logout"}) == "Log out octavia.butler@example.com"

    click({:css, "a.logout"})

    assert visible_text({:css, "a.login"}) == "Log in"
    assert visible_text({:css, "a.register"}) == "Register"
    assert visible_text({:css, ".alert-info"}) == "Logged out"
  end

  test "logging in as an admin" do
    Forge.saved_user email: "francine.pascal@example.com"
    Forge.saved_user email: "octavia.butler@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Xenogenesis"), admin: true

    navigate_to "/"

    click({:link_text, "Log in"})

    fill_field({:id, "email"}, "octavia.butler@example.com")
    fill_field({:id, "password"}, "Xenogenesis")
    click({:class, "btn"})

    click({:css, "a.users"})
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
