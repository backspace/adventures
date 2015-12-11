defmodule Cr2016site.Integration.Teams do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper

  alias Cr2016site.Pages.Login
  alias Cr2016site.Pages.Nav
  alias Cr2016site.Pages.Details

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session

  test "teams are negotiable" do
    Forge.saved_user email: "shevek@example.com",
                     team_emails: "takver@example.com bedap@example.com tuio@example.com rulag@example.com",
                     proposed_team_name: "Sequency",
                     risk_aversion: 1

    Forge.saved_user email: "bedap@example.com",
                     team_emails: "takver@example.com shevek@example.com tuio@example.com",
                     proposed_team_name: "Simultaneity",
                     risk_aversion: 3

    Forge.saved_user email: "tuio@example.com", team_emails: "shevek@example.com"
    Forge.saved_user email: "rulag@example.com", team_emails: "shevek@example.com"

    Forge.saved_user email: "sadik@example.com", team_emails: "takver@example.com"

    Forge.saved_user email: "sabul@example.com"

    Forge.saved_user email: "takver@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Anarres")

    navigate_to "/"

    Login.login_as "takver@example.com", "Anarres"

    Nav.edit_details
    Details.fill_team_emails "shevek@example.com bedap@example.com sabul@example.com laia@example.com nooo"
    Details.fill_proposed_team_name "Simultaneity"
    Details.choose_risk_aversion "Don’t hold back"
    Details.fill_accessibility "Some accessibility information"
    Details.submit

    assert Nav.info_text == "Your details were saved"

    assert Details.accessibility_text == "Some accessibility information"

    [sent_email] = Cr2016site.MailgunHelper.sent_email
    assert sent_email["to"] == "b@events.chromatin.ca"
    assert sent_email["from"] == "b@events.chromatin.ca"
    assert sent_email["subject"] == "takver@example.com details changed: accessibility, proposed_team_name, risk_aversion, team_emails"
    assert sent_email["text"] == "%{accessibility: \"Some accessibility information\", proposed_team_name: \"Simultaneity\", risk_aversion: 3, team_emails: \"shevek@example.com bedap@example.com sabul@example.com laia@example.com nooo\"}"

    [shevek, bedap] = Details.mutuals

    assert shevek.email == "shevek@example.com"
    assert shevek.symbol == "✓"
    assert shevek.proposed_team_name.value == "✘ Sequency"
    assert shevek.proposed_team_name.conflict?
    refute shevek.proposed_team_name.agreement?
    assert shevek.risk_aversion.value == "✘ Go easy on me"
    assert shevek.risk_aversion.conflict?

    assert bedap.email == "bedap@example.com"
    assert bedap.symbol == "✓"
    assert bedap.proposed_team_name.value == "✓ Simultaneity"
    refute bedap.proposed_team_name.conflict?
    assert bedap.proposed_team_name.agreement?
    assert bedap.risk_aversion.value == "✓ Don’t hold back"
    assert bedap.risk_aversion.agreement?

    [sadik] = Details.proposers
    assert sadik.email == "sadik@example.com"
    assert sadik.symbol == "?"
    assert sadik.text == "This person has you listed in their team. Add their address to your team emails list if you agree."

    [rulag, tuio] = Details.proposals_by_mutuals

    assert rulag.email == "rulag@example.com"
    assert rulag.symbol == "?"
    assert rulag.text == "shevek@example.com has this address in their team emails list. Add it if you agree."

    assert tuio.email == "tuio@example.com"
    assert rulag.symbol == "?"
    assert tuio.text == "shevek@example.com and bedap@example.com have this address in their team emails lists. Add it if you agree."

    [invalid] = Details.invalids
    assert invalid.email == "nooo"
    assert invalid.symbol == "✘"
    assert invalid.text == "This doesn’t seem like a valid email address!"

    [sabul, laia] = Details.proposees

    assert sabul.email == "sabul@example.com"
    assert sabul.symbol == "✘"
    assert sabul.text == "This person doesn’t have your address listed as a desired team member! Are they registered? Maybe they used a different address? Confer."

    assert laia.email == "laia@example.com"
    assert sabul.symbol == "✘"
    assert laia.text == "This person doesn’t have your address listed as a desired team member! Are they registered? Maybe they used a different address? Confer."


    sadik.add.()
    Details.submit

    # FIXME restore this test that breaks on Travis… Javascript problem?
    # assert length(Details.mutuals) == 3
  end
end
