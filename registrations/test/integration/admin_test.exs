defmodule Registrations.Integration.Admin do
  @moduledoc false
  use RegistrationsWeb.FeatureCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "clandestine-rendezvous"

  import Assertions, only: [assert_lists_equal: 2]

  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav
  alias Registrations.Pages.Teams
  alias Registrations.Pages.Users
  alias Wallaby.Query

  require Assertions

  test "logging in as an admin", %{session: session} do
    user =
      insert(:user,
        email: "francine.pascal@example.com",
        accessibility: "Some accessibility text",
        attending: true
      )

    admin = insert(:octavia, admin: true, proposed_team_name: "Admins", attending: false)
    blank_attending = insert(:user, email: "blank@example.com")

    visit(session, "/")

    Nav.login_link().click(session)

    Login.fill_email(session, "octavia.butler@example.com")
    Login.fill_password(session, "Xenogenesis")
    Login.submit(session)

    refute has?(session, Query.css("a.settings"))

    Nav.users_link().click(session)

    assert Users.email(session, user.id) == "francine.pascal@example.com"
    assert Users.accessibility(session, user.id) == "Some accessibility text"
    assert Users.attending(session, user.id) == "✓"

    assert Users.email(session, admin.id) == admin.email
    assert Users.proposed_team_name(session, admin.id) == "Admins"
    assert Users.attending(session, admin.id) == "✘"

    assert Users.attending(session, blank_attending.id) == "?"
  end

  test "admin can build teams", %{session: session} do
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

    visit(session, "/")
    Login.login_as_admin(session)

    Nav.users_link().click(session)

    refute Users.teamed(session, a.id)
    refute Users.teamed(session, b.id)
    refute Users.teamed(session, c.id)

    Users.build_team_from(session, a.id)

    assert Nav.info_text(session) == "Team built successfully"

    assert Users.teamed(session, a.id)
    assert Users.teamed(session, b.id)
    refute Users.teamed(session, c.id)

    assert_lists_equal(Users.all_emails(session), [
      "c@example.com",
      "octavia.butler@example.com",
      "not-attending@example.com",
      "a@example.com",
      "b@example.com"
    ])

    Nav.teams_link().click(session)

    assert Teams.name(session, 1) == "Team A"
    assert Teams.risk_aversion(session, 1) == "3"
    assert Teams.emails(session, 1) == "a@example.com, b@example.com"

    [team] = Registrations.Repo.all(RegistrationsWeb.Team)
    assert team.name == "Team A"
    assert team.risk_aversion == 3
    refute team.notes
  end

  test "teams without any name proposals or risk aversions get placeholders", %{
    session: session
  } do
    a =
      insert(:user,
        email: "a@example.com",
        team_emails: "",
        accessibility: "Some text"
      )

    insert(:octavia, admin: true)

    visit(session, "/")
    Login.login_as_admin(session)

    Nav.users_link().click(session)
    Users.build_team_from(session, a.id)

    assert Nav.error_text(session) == "Team built with placeholders!"

    Nav.teams_link().click(session)

    assert Teams.name(session, 1) == "FIXME"
    assert Teams.risk_aversion(session, 1) === "1"
  end

  test "admin can view team JSON", %{session: session} do
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

    visit(session, "/")
    Login.login_as_admin(session)

    visit(session, "/api/teams")
    json = session |> page_source() |> Floki.find("pre") |> Floki.text() |> Jason.decode!()

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

  test "non-admins cannot access the user list or messages", %{session: session} do
    insert(:user, email: "francine.pascal@example.com")

    assert Nav.users_link().absent?(session)

    visit(session, "/users")

    refute page_source(session) =~ "francine.pascal@example.com"

    visit(session, "/messages")
    assert Nav.error_text(session) == "Who are you?"

    visit(session, "/teams")
    assert Nav.error_text(session) == "Who are you?"

    visit(session, "/settings")
    assert Nav.error_text(session) == "Who are you?"
  end
end

defmodule Registrations.Integration.UnmnemonicDevices.Admin do
  @moduledoc false
  use RegistrationsWeb.FeatureCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "unmnemonic-devices"

  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav
  alias Wallaby.Query

  test "admin can create and update settings", %{session: session} do
    insert(:octavia, admin: true)

    visit(session, "/")

    Nav.login_link().click(session)

    Login.fill_email(session, "octavia.butler@example.com")
    Login.fill_password(session, "Xenogenesis")
    Login.submit(session)

    Nav.settings_link().click(session)

    refute has?(session, Query.css("#settings_begun:checked"))

    fill_in(session, Query.css("#settings_override"), with: "an override")
    click(session, Query.css("#settings_begun"))

    click(session, Query.css("button[type=submit]"))

    assert current_path(session) == "/settings"

    assert has?(session, Query.css("#settings_begun:checked"))
    assert text(session, Query.css(".alert-info")) == "Settings updated successfully."
  end

  test "non-admins cannot access the user list or messages", %{session: session} do
    insert(:user, email: "francine.pascal@example.com")

    visit(session, "/settings")
    assert Nav.error_text(session) == "Who are you?"
  end

  test "admin can view team JSON that includes voicepasses", %{session: session} do
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

    visit(session, "/")
    Login.login_as_admin(session)

    visit(session, "/api/teams")
    json = session |> page_source() |> Floki.find("pre") |> Floki.text() |> Jason.decode!()

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
