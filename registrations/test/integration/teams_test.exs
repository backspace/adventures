defmodule Registrations.Integration.Teams do
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "clandestine-rendezvous"

  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav
  alias Registrations.Pages.Details

  require Assertions
  import Assertions, only: [assert_lists_equal: 2]

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session(Registrations.ChromeHeadlessHelper.additional_capabilities())

  test "teams are negotiable" do
    insert(:user,
      email: "Shevek@example.com",
      team_emails: "Takver@example.com bedap@example.com tuio@example.com rulag@example.com",
      proposed_team_name: "Sequency",
      risk_aversion: 1
    )

    insert(:user,
      email: "bedap@example.com",
      team_emails: "takver@example.com shevek@example.com tuio@example.com",
      proposed_team_name: "Simultaneity",
      risk_aversion: 3
    )

    insert(:user, email: "tuio@example.com", team_emails: "shevek@example.com")
    insert(:user, email: "rulag@example.com", team_emails: "shevek@example.com")

    insert(:user, email: "sadik@example.com", team_emails: "takver@example.com")

    insert(:user, email: "sabul@example.com")

    insert(:user,
      email: "takver@example.com",
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Anarres")
    )

    navigate_to("/")

    Login.login_as("takver@example.com", "Anarres")

    refute Details.Attending.present?(), "Expected attending fields to be hidden unless enabled"
    refute Details.Team.present?(), "Expected no team block for an unassigned user"

    Details.fill_team_emails(
      "shevek@example.com bedap@example.com sabul@example.com laia@example.com nooo"
    )

    Details.fill_proposed_team_name("Simultaneity")
    Details.choose_risk_aversion("Don’t hold back")
    Details.fill_accessibility("Some accessibility information")

    Details.comments().fill("Some comments")
    Details.source().fill("A source")

    Details.submit()

    assert Nav.info_text() == "Your details were saved"

    assert Details.accessibility_text() == "Some accessibility information"
    assert Details.comments().value() == "Some comments"
    assert Details.source().value() == "A source"

    [sent_email] = Registrations.SwooshHelper.sent_email()
    assert sent_email.to == [{"", "b@events.chromatin.ca"}]
    assert sent_email.from == {"", "b@events.chromatin.ca"}

    assert sent_email.subject ==
             "takver@example.com details changed: accessibility, comments, proposed_team_name, risk_aversion, source, team_emails"

    assert sent_email.text_body ==
             "[accessibility: \"Some accessibility information\", comments: \"Some comments\", proposed_team_name: \"Simultaneity\", risk_aversion: 3, source: \"A source\", team_emails: \"shevek@example.com bedap@example.com sabul@example.com laia@example.com nooo\"]"

    [bedap, shevek] = Details.mutuals() |> Enum.sort_by(& &1.email)

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

    [sadik] = Details.proposers()
    assert sadik.email == "sadik@example.com"
    assert sadik.symbol == "?"

    assert sadik.text ==
             "This person has you listed in their team. Add their address to your team emails list if you agree."

    [rulag, tuio] = Details.proposals_by_mutuals() |> Enum.sort_by(& &1.email)

    assert rulag.email == "rulag@example.com"
    assert rulag.symbol == "?"

    assert rulag.text ==
             "shevek@example.com has this address in their team emails list. Add it if you agree."

    assert tuio.email == "tuio@example.com"
    assert rulag.symbol == "?"

    assert tuio.text ==
             "shevek@example.com and bedap@example.com have this address in their team emails lists. Add it if you agree."

    [invalid] = Details.invalids()
    assert invalid.email == "nooo"
    assert invalid.symbol == "✘"
    assert invalid.text == "This doesn’t seem like a valid email address!"

    [laia, sabul] = Details.proposees() |> Enum.sort_by(& &1.email)

    assert sabul.email == "sabul@example.com"
    assert sabul.symbol == "✘"

    assert String.starts_with?(
             sabul.text,
             "This person doesn’t have your address listed as a desired team member! Are they registered? Maybe they used a different address? Confer."
           )

    assert laia.email == "laia@example.com"
    assert sabul.symbol == "✘"

    assert String.starts_with?(
             laia.text,
             "This person doesn’t have your address listed as a desired team member! Are they registered? Maybe they used a different address? Confer."
           )

    sadik.add.()
    Details.submit()

    assert length(Details.mutuals()) == 3
  end

  test "team emails can be appended to" do
    insert(:user,
      email: "Shevek@example.com",
      team_emails: "Takver@example.com bedap@example.com tuio@example.com rulag@example.com",
      proposed_team_name: "Sequency",
      risk_aversion: 1
    )

    insert(:user,
      email: "takver@example.com",
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Anarres")
    )

    navigate_to("/")

    Login.login_as("takver@example.com", "Anarres")

    assert Details.team_emails() == ""

    Details.add_to_team_emails()

    assert Details.team_emails() == " shevek@example.com"
  end

  test "the table is hidden when empty" do
    insert(:user,
      email: "takver@example.com",
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Anarres")
    )

    navigate_to("/")

    Login.login_as("takver@example.com", "Anarres")

    refute Hound.Matchers.element?(:css, "table")
  end

  test "when confirmation-requesting is enabled, show and require the fields" do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :request_confirmation,
      true
    )

    insert(:user,
      email: "takver@example.com",
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Anarres")
    )

    navigate_to("/")

    Login.login_as("takver@example.com", "Anarres")

    assert Details.Attending.present?(), "Expected attending fields shown when enabled"

    Details.submit()

    assert Details.Attending.Error.present?(),
           "Expected an error about the attending field being blank"

    Details.Attending.yes()
    Details.submit()

    refute Details.Attending.Error.present?(),
           "Expected no error when the person said they were attending"

    Details.Attending.no()
    Details.submit()

    refute Details.Attending.Error.present?(),
           "Expected no error when the person said they were not attending"
  end

  test "visiting the details page redirects to login when there is no session" do
    navigate_to("/details")

    assert Nav.info_text() == "Please log in to edit your details"
    Login.fill_email("anemail")
  end

  test "team details are shown if the user is assigned to one" do
    takver =
      insert(:user,
        email: "takver@example.com",
        password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Anarres")
      )

    bedap =
      insert(:user,
        email: "bedap@example.com",
        password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Anarres")
      )

    insert(:team,
      name: "A team",
      risk_aversion: 2,
      notes: "Some notes",
      users: [takver, bedap]
    )

    navigate_to("/")

    Login.login_as("takver@example.com", "Anarres")

    assert Details.Team.present?()
    assert Details.Team.name() == "A team"
    assert Details.Team.risk_aversion() == "Push me a little"

    assert_lists_equal(Details.Team.emails() |> String.split(", "), [
      "takver@example.com",
      "bedap@example.com"
    ])
  end
end

defmodule Registrations.Integration.UnmnemonicDevices.Teams do
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "unmnemonic-devices"

  alias Registrations.Pages.Login
  alias Registrations.Pages.Details

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session(Registrations.ChromeHeadlessHelper.additional_capabilities())

  test "team emails can be appended to" do
    insert(:user,
      email: "Shevek@example.com",
      team_emails: "Takver@example.com bedap@example.com tuio@example.com rulag@example.com",
      proposed_team_name: "Sequency",
      risk_aversion: 1
    )

    insert(:user,
      email: "takver@example.com",
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Anarres")
    )

    navigate_to("/")

    Login.login_as("takver@example.com", "Anarres")

    assert Details.team_emails() == ""

    Details.add_to_team_emails()

    assert Details.team_emails() == " shevek@example.com"
  end
end
