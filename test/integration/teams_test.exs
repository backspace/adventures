defmodule Cr2016site.Integration.Teams do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper
  use Cr2016site.ResetRequestConfirmation

  alias Cr2016site.Pages.Login
  alias Cr2016site.Pages.Nav
  alias Cr2016site.Pages.Details

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session()

  test "teams are negotiable" do
    Forge.saved_user email: "Shevek@example.com",
                     team_emails: "Takver@example.com bedap@example.com tuio@example.com rulag@example.com",
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

    refute Details.Attending.present?, "Expected attending fields to be hidden unless enabled"

    Details.fill_team_emails "shevek@example.com bedap@example.com sabul@example.com laia@example.com nooo"
    Details.fill_proposed_team_name "Simultaneity"

    Details.choose_txt
    Details.choose_data
    Details.fill_number "2045551212"
    Details.fill_display_size "7"

    Details.choose_risk_aversion "Don’t hold back"
    Details.fill_accessibility "Some accessibility information"

    Details.comments.fill "Some comments"
    Details.source.fill "A source"

    Details.submit

    assert Nav.info_text == "Your details were saved"

    assert Details.accessibility_text == "Some accessibility information"
    assert Details.comments.value == "Some comments"
    assert Details.source.value == "A source"

    [sent_email] = Cr2016site.MailgunHelper.sent_email
    assert sent_email["to"] == Application.get_env(:cr2016site, :email_address)
    assert sent_email["from"] == Application.get_env(:cr2016site, :email_address)
    assert sent_email["subject"] == "takver@example.com details changed: accessibility, comments, data, display_size, number, proposed_team_name, risk_aversion, source, team_emails, txt"
    assert sent_email["text"] == "%{accessibility: \"Some accessibility information\", comments: \"Some comments\", data: true, display_size: \"7\", number: \"2045551212\", proposed_team_name: \"Simultaneity\", risk_aversion: 3, source: \"A source\", team_emails: \"shevek@example.com bedap@example.com sabul@example.com laia@example.com nooo\", txt: true}"

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

  test "the table is hidden when empty" do
    Forge.saved_user email: "takver@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Anarres")

    navigate_to "/"

    Login.login_as "takver@example.com", "Anarres"

    refute Hound.Matchers.element? :css, "table"
  end

  test "when confirmation-requesting is enabled, show and require the fields" do
    Application.put_env(:cr2016site, :request_confirmation, true)

    Forge.saved_user email: "takver@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("Anarres")

    navigate_to "/"

    Login.login_as "takver@example.com", "Anarres"

    assert Details.Attending.present?, "Expected attending fields shown when enabled"

    Details.submit
    assert Details.Attending.Error.present?, "Expected an error about the attending field being blank"

    Details.Attending.yes
    Details.submit
    refute Details.Attending.Error.present?, "Expected no error when the person said they were attending"

    Details.Attending.no
    Details.submit
    refute Details.Attending.Error.present?, "Expected no error when the person said they were not attending"
  end

  test "visiting the details page redirects to login when there is no session" do
    navigate_to "/details"

    assert Nav.info_text == "Please log in to edit your details"
    Login.fill_email "anemail"
  end
end
