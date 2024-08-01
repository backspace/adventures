defmodule Registrations.Integration.Invitations do
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.ResetRequestConfirmation
  use Registrations.ClandestineRendezvous

  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav
  alias Registrations.Pages.Details
  alias Registrations.Pages.Register

  use Hound.Helpers
  hound_session(Registrations.ChromeHeadlessHelper.additional_capabilities())

  test "can invite a user, who can accept" do
    insert(:user,
      email: "shevek@example.com",
      team_emails: "bedap@example.com",
      proposed_team_name: "Sequency",
      risk_aversion: 1,
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("Anarres")
    )

    navigate_to("/")

    Login.login_as("shevek@example.com", "Anarres")

    assert Details.InviteButton.present?()

    Details.InviteButton.click()

    refute Details.InviteButton.present?()

    [invitation_email] = Registrations.SwooshHelper.sent_email()
    assert invitation_email.to == [{"", "bedap@example.com"}]
    assert invitation_email.from == {"", "b@events.chromatin.ca"}

    assert invitation_email.subject ==
             "[rendezvous] You've been invited"

    [url] =
      Floki.find(invitation_email.html_body, "a")
      |> Floki.attribute("href")

    reset_path = URI.parse(url).path

    Hound.Helpers.Session.end_session()

    Hound.Helpers.Session.start_session(
      Registrations.ChromeHeadlessHelper.additional_capabilities()
    )

    navigate_to(reset_path)
    Register.fill_email("bedap@example.com")
    Register.fill_password("simulteneity")
    Register.fill_password_confirmation("simulteneity")
    Register.submit()

    assert Nav.logout_link().text == "Log out bedap@example.com"
  end
end
