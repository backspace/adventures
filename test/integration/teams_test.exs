defmodule Cr2016site.Integration.Teams do
  use Cr2016site.ConnCase

  alias Cr2016site.Pages.Login
  alias Cr2016site.Pages.Nav
  alias Cr2016site.Pages.Details

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session

  test "teams are negotiable" do
    Forge.saved_user email: "shevek@example.com", team_emails: "takver@example.com"
    Forge.saved_user email: "sadik@example.com", team_emails: "takver@example.com"

    Forge.saved_user email: "takver@example.com", team_emails: "shevek@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Anarres")

    navigate_to "/"

    Nav.login_link.click

    Login.fill_email "takver@example.com"
    Login.fill_password "Anarres"
    Login.submit

    Nav.edit_details

    assert Details.mutuals == "shevek@example.com"
    assert Details.proposers == "sadik@example.com"
  end
end
