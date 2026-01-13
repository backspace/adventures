defmodule Registrations.Integration.Invitations do
  @moduledoc false
  use RegistrationsWeb.FeatureCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "clandestine-rendezvous"

  alias Registrations.Pages.Details
  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav
  alias Registrations.Pages.Register

  test "can invite a user, who can accept", %{
    session: session,
    wallaby_metadata: wallaby_metadata
  } do
    insert(:user,
      email: "shevek@example.com",
      team_emails: "bedap@example.com",
      proposed_team_name: "Sequency",
      risk_aversion: 1,
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Anarres")
    )

    visit(session, "/")

    Login.login_as(session, "shevek@example.com", "Anarres")

    assert Details.InviteButton.present?(session)

    Details.InviteButton.click(session)

    refute Details.InviteButton.present?(session)

    [invitation_email] = Registrations.SwooshHelper.sent_email()
    assert invitation_email.to == [{"", "bedap@example.com"}]
    assert invitation_email.from == {"", "b@events.chromatin.ca"}

    assert invitation_email.subject ==
             "[rendezvous] You've been invited"

    [url] =
      invitation_email.html_body
      |> Floki.find("a")
      |> Floki.attribute("href")

    reset_path = URI.parse(url).path

    {:ok, session} = Wallaby.start_session(metadata: wallaby_metadata)

    on_exit(fn -> Wallaby.end_session(session) end)

    visit(session, reset_path)
    Register.fill_email(session, "bedap@example.com")
    Register.fill_password(session, "simulteneity")
    Register.fill_password_confirmation(session, "simulteneity")
    Register.submit(session)

    assert Nav.logout_link().text(session) == "Log out bedap@example.com"
  end
end
