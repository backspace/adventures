defmodule Cr2016site.Integration.Admin do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper

  alias Cr2016site.Pages.Login
  alias Cr2016site.Pages.Nav
  alias Cr2016site.Pages.Users

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session

  test "logging in as an admin" do
    {_, user} = Forge.saved_user email: "francine.pascal@example.com", accessibility: "Some accessibility text"
    {_, admin} = Forge.saved_octavia admin: true, proposed_team_name: "Admins"

    navigate_to "/"

    Nav.login_link.click

    Login.fill_email "octavia.butler@example.com"
    Login.fill_password "Xenogenesis"
    Login.submit

    Nav.users_link.click

    assert Users.email(user.id) == "francine.pascal@example.com"
    assert Users.accessibility(user.id) == "Some accessibility text"

    assert Users.email(admin.id) == admin.email
    assert Users.proposed_team_name(admin.id) == "Admins"
  end

  test "non-admins cannot access the user list or messages" do
    Forge.saved_user email: "francine.pascal@example.com"

    assert Nav.users_link.absent?

    navigate_to "/users"

    refute page_source =~ "francine.pascal@example.com"

    navigate_to "/messages"
    assert Nav.error_text == "Who are you?"
  end
end
