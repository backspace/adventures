defmodule Registrations.Integration.Admin do
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "clandestine-rendezvous"

  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav
  alias Registrations.Pages.Users
  alias Registrations.Pages.Teams

  require Assertions
  import Assertions, only: [assert_lists_equal: 2]

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session(Registrations.ChromeHeadlessHelper.additional_capabilities())

  test "logging in as an admin" do
    user =
      insert(:user,
        email: "francine.pascal@example.com",
        accessibility: "Some accessibility text",
        attending: true
      )

    admin = insert(:octavia, admin: true, proposed_team_name: "Admins", attending: false)
    blank_attending = insert(:user, email: "blank@example.com")

    navigate_to("/")

    Nav.login_link().click

    Login.fill_email("octavia.butler@example.com")
    Login.fill_password("Xenogenesis")
    Login.submit()

    refute element?(:css, "a.settings")

    Nav.users_link().click

    assert Users.email(user.id) == "francine.pascal@example.com"
    assert Users.accessibility(user.id) == "Some accessibility text"
    assert Users.attending(user.id) == "✓"

    assert Users.email(admin.id) == admin.email
    assert Users.proposed_team_name(admin.id) == "Admins"
    assert Users.attending(admin.id) == "✘"

    assert Users.attending(blank_attending.id) == "?"
  end

  test "admin can build teams" do
    a =
      insert(:user,
        email: "a@example.com",
        attending: true,
        proposed_team_name: "Team A",
        team_emails: "b@example.com",
        risk_aversion: 3,
        accessibility: "Some text"
      )

    b =
      insert(:user,
        email: "b@example.com",
        attending: true,
        proposed_team_name: "Team B",
        team_emails: "a@example.com",
        risk_aversion: 1,
        accessibility: "More text"
      )

    insert(:user, email: "not-attending@example.com", attending: false)

    c =
      insert(:user,
        email: "c@example.com",
        attending: true,
        team_emails: "a@example.com b@example.com"
      )

    insert(:octavia, admin: true)

    navigate_to("/")
    Login.login_as_admin()

    Nav.users_link().click

    refute Users.teamed(a.id)
    refute Users.teamed(b.id)
    refute Users.teamed(c.id)

    Users.build_team_from(a.id)

    assert Nav.info_text() == "Team built successfully"

    assert Users.teamed(a.id)
    assert Users.teamed(b.id)
    refute Users.teamed(c.id)

    assert_lists_equal(Users.all_emails(), [
      "c@example.com",
      "octavia.butler@example.com",
      "not-attending@example.com",
      "a@example.com",
      "b@example.com"
    ])

    Nav.teams_link().click

    assert Teams.name(1) == "Team A"
    assert Teams.risk_aversion(1) == "3"
    assert Teams.emails(1) == "a@example.com, b@example.com"

    [team] = Registrations.Repo.all(RegistrationsWeb.Team)
    assert team.name == "Team A"
    assert team.risk_aversion == 3
    refute team.notes
  end

  test "teams without any name proposals or risk aversions get placeholders" do
    a =
      insert(:user,
        email: "a@example.com",
        team_emails: "",
        accessibility: "Some text"
      )

    insert(:octavia, admin: true)

    navigate_to("/")
    Login.login_as_admin()

    Nav.users_link().click
    Users.build_team_from(a.id)

    assert Nav.error_text() == "Team built with placeholders!"

    Nav.teams_link().click

    assert Teams.name(1) == "FIXME"
    assert Teams.risk_aversion(1) === "1"
  end

  test "admin can view team JSON" do
    a = insert(:user, accessibility: "my notes", email: "a@example.com")
    b = insert(:user, email: "b@example.com")

    team =
      insert(:team,
        name: "A team",
        risk_aversion: 2,
        notes: "Some notes",
        users: [a, b]
      )

    insert(:octavia, admin: true)

    navigate_to("/")
    Login.login_as_admin()

    navigate_to("/api/teams")
    json = Floki.find(page_source(), "pre") |> Floki.text() |> Jason.decode!()

    assert json == %{
             "data" => [
               %{
                 "type" => "teams",
                 "id" => team.id,
                 "attributes" => %{
                   "name" => "A team",
                   "notes" => "Some notes\n\na@example.com: my notes",
                   "users" => "a@example.com, b@example.com",
                   "riskAversion" => 2,
                   "createdAt" => NaiveDateTime.to_iso8601(team.inserted_at),
                   "updatedAt" => NaiveDateTime.to_iso8601(team.updated_at)
                 }
               }
             ]
           }
  end

  test "non-admins cannot access the user list or messages" do
    insert(:user, email: "francine.pascal@example.com")

    assert Nav.users_link().absent?

    navigate_to("/users")

    refute page_source() =~ "francine.pascal@example.com"

    navigate_to("/messages")
    assert Nav.error_text() == "Who are you?"

    navigate_to("/teams")
    assert Nav.error_text() == "Who are you?"

    navigate_to("/settings")
    assert Nav.error_text() == "Who are you?"
  end
end

defmodule Registrations.Integration.UnmnemonicDevices.Admin do
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "unmnemonic-devices"

  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav

  use Hound.Helpers

  hound_session(Registrations.ChromeHeadlessHelper.additional_capabilities())

  test "admin can create and update settings" do
    insert(:octavia, admin: true)

    navigate_to("/")

    Nav.login_link().click

    Login.fill_email("octavia.butler@example.com")
    Login.fill_password("Xenogenesis")
    Login.submit()

    Nav.settings_link().click

    refute selected?({:id, "settings_begun"})

    fill_field({:id, "settings_override"}, "an override")
    click({:id, "settings_begun"})

    click({:css, "button[type=submit]"})

    assert current_path() == "/settings"

    assert selected?({:id, "settings_begun"})
    assert visible_text({:css, ".alert-info"}) == "Settings updated successfully."
  end

  test "non-admins cannot access the user list or messages" do
    insert(:user, email: "francine.pascal@example.com")

    navigate_to("/settings")
    assert Nav.error_text() == "Who are you?"
  end

  test "admin can view team JSON that includes voicepasses" do
    a = insert(:user, email: "a@example.com")
    b = insert(:user, email: "b@example.com")

    team =
      insert(:team,
        name: "A team",
        risk_aversion: 2,
        notes: "Some notes",
        voicepass: "A voicepass",
        users: [a, b]
      )

    insert(:octavia, admin: true)

    navigate_to("/")
    Login.login_as_admin()

    navigate_to("/api/teams")
    json = Floki.find(page_source(), "pre") |> Floki.text() |> Jason.decode!()

    assert json == %{
             "data" => [
               %{
                 "type" => "teams",
                 "id" => team.id,
                 "attributes" => %{
                   "name" => "A team",
                   "identifier" => "A voicepass",
                   "notes" => "Some notes\n",
                   "users" => "a@example.com, b@example.com",
                   "riskAversion" => 2,
                   "createdAt" => NaiveDateTime.to_iso8601(team.inserted_at),
                   "updatedAt" => NaiveDateTime.to_iso8601(team.updated_at)
                 }
               }
             ]
           }
  end
end
