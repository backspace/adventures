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
    Forge.saved_user email: "shevek@example.com", team_emails: "takver@example.com bedap@example.com tuio@example.com rulag@example.com"
    Forge.saved_user email: "bedap@example.com", team_emails: "takver@example.com shevek@example.com tuio@example.com"
    Forge.saved_user email: "tuio@example.com", team_emails: "shevek@example.com"
    Forge.saved_user email: "rulag@example.com", team_emails: "shevek@example.com"

    Forge.saved_user email: "sadik@example.com", team_emails: "takver@example.com"

    Forge.saved_user email: "takver@example.com", team_emails: "shevek@example.com bedap@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Anarres")

    navigate_to "/"

    Login.login_as "takver@example.com", "Anarres"

    Nav.edit_details

    [shevek, bedap] = Details.mutuals

    assert shevek.email == "shevek@example.com"

    assert bedap.email == "bedap@example.com"

    assert Details.proposers == "sadik@example.com"
    assert Details.proposals_by_mutuals ==
      [
        "rulag@example.com: shevek@example.com has this address in their team emails list. Add it if you agree.",
        "tuio@example.com: shevek@example.com and bedap@example.com have this address in their team emails lists. Add it if you agree."
      ]
  end
end
