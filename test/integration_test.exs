defmodule Cr2016site.IntegrationTest do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session

  test "registering" do
    navigate_to "/"
    click({:link_text, "Register"})

    click({:class, "btn"})
    assert visible_text({:css, ".alert-info"}) == "Unable to create account"
    assert visible_text({:css, ".errors .email"}) == "Email has invalid format"
    assert visible_text({:css, ".errors .password"}) == "Password should be at least 5 characters"

    fill_field({:id, "email"}, "franklin.w.dixon@example.com")
    click({:class, "btn"})
    assert visible_text({:css, ".alert-info"}) == "Unable to create account"

    fill_field({:id, "email"}, "samuel.delaney@example.com")
    fill_field({:id, "password"}, "nestofspiders")
    click({:class, "btn"})

    assert visible_text({:css, ".alert-info"}) == "Your account was created"

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
end
