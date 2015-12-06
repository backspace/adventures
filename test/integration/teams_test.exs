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

    Forge.saved_user email: "takver@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Anarres")

    navigate_to "/"

    Login.login_as "takver@example.com", "Anarres"

    Nav.edit_details
    Details.fill_team_emails "shevek@example.com bedap@example.com"
    Details.submit

    assert Nav.alert_text == "Your details were saved"

    [shevek, bedap] = Details.mutuals

    assert shevek.email == "shevek@example.com"

    assert bedap.email == "bedap@example.com"

    [sadik] = Details.proposers
    assert sadik.email == "sadik@example.com"
    assert sadik.text == "This person has you listed in their team. Add their address to your team emails list if you agree."

    [rulag, tuio] = Details.proposals_by_mutuals

    assert rulag.email == "rulag@example.com"
    assert rulag.text == "shevek@example.com has this address in their team emails list. Add it if you agree."

    assert tuio.email == "tuio@example.com"
    assert tuio.text == "shevek@example.com and bedap@example.com have this address in their team emails lists. Add it if you agree."
  end
end
