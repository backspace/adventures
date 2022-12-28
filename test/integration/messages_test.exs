defmodule AdventureRegistrations.Integration.Messages do
  use AdventureRegistrationsWeb.ConnCase
  use AdventureRegistrations.SwooshHelper

  alias AdventureRegistrations.Pages.Login
  alias AdventureRegistrations.Pages.Register
  alias AdventureRegistrations.Pages.Messages
  alias AdventureRegistrations.Pages.Nav

  use Hound.Helpers
  hound_session()

  test "a message is sent to all registrants with their team information summarised" do
    Forge.saved_admin(
      email: "admin@example.com",
      crypted_password: Comeonin.Bcrypt.hashpwsalt("admin")
    )

    Forge.saved_user(
      email: "user@example.com",
      team_emails: "teammate@example.com",
      proposed_team_name: "Jorts"
    )

    Forge.saved_user(
      email: "teammate@example.com",
      team_emails: "user@example.com",
      proposed_team_name: "Jants"
    )

    Forge.saved_user(email: "empty@example.com")

    navigate_to("/")

    Login.login_as("admin@example.com", "admin")
    Nav.edit_messages()

    Messages.new_message()

    Messages.fill_subject("A Subject!")
    Messages.fill_content("This is the content.")
    Messages.check_ready()
    Messages.save()

    Messages.send()

    assert Nav.info_text() == "Message was sent"

    [empty_email, _, email, _] = AdventureRegistrations.SwooshHelper.sent_email()
    assert email.to == [{"", "user@example.com"}]
    assert email.from == {"", "b@events.chromatin.ca"}
    assert email.subject == "[rendezvous] A Subject!"

    text = email.text_body
    assert String.contains?(text, "Jorts")
    assert String.contains?(text, "Jants")

    assert String.contains?(empty_email.text_body, "You haven’t filled in any details!")
  end

  test "a message with show team enabled shows the actual team information instead of their details" do
    Forge.saved_admin(
      email: "admin@example.com",
      crypted_password: Comeonin.Bcrypt.hashpwsalt("admin")
    )

    {_, team_member_1} =
      Forge.saved_user(
        email: "user-with-team@example.com",
        team_emails: "teammate@example.com",
        proposed_team_name: "Ignored team name"
      )

    {_, team_member_2} = Forge.saved_user(email: "teammate@example.com")
    Forge.saved_user(email: "teamless-user@example.com")

    Forge.saved_team(
      name: "True team name",
      risk_aversion: 1,
      user_ids: [team_member_1.id, team_member_2.id]
    )

    navigate_to("/")

    Login.login_as("admin@example.com", "admin")
    Nav.edit_messages()

    Messages.new_message()

    Messages.fill_subject("A Subject!")
    Messages.fill_content("ya")
    Messages.check_ready()
    Messages.check_show_team()
    Messages.save()

    Messages.send()

    [has_no_team_email, _, has_team_email, _] = AdventureRegistrations.SwooshHelper.sent_email()

    assert has_team_email.to == [{"", "user-with-team@example.com"}]
    assert String.contains?(has_team_email.text_body, "True team name")
    assert String.contains?(has_team_email.text_body, "Go easy on me")

    assert has_no_team_email.to == [{"", "teamless-user@example.com"}]
    assert String.contains?(has_no_team_email.text_body, "You have no team assigned!")
  end

  test "the backlog of existing messages is sent to a new registrant after the welcome" do
    Forge.saved_message(subject: "Subject one", content: "Content one")
    Forge.saved_message(subject: "Subject two", content: "Content two")
    Forge.saved_not_ready_message(subject: "Not ready", content: "Not ready")

    navigate_to("/")
    Nav.register_link().click

    Register.fill_email("registerer@example.com")
    Register.fill_password("abcdefghi")
    Register.submit()

    [backlog_email, _welcome_, _admin] = AdventureRegistrations.SwooshHelper.sent_email()

    assert backlog_email.to == [{"", "registerer@example.com"}]
    assert backlog_email.from == {"", "b@events.chromatin.ca"}

    assert backlog_email.subject == "[rendezvous] Messages sent before you registered"

    text = backlog_email.text_body
    assert String.contains?(text, "These messages were sent before you registered.")

    assert String.contains?(text, "Subject one")
    assert String.contains?(text, "Content one")

    assert String.contains?(text, "Subject two")
    assert String.contains?(text, "Content two")

    refute String.contains?(text, "Not ready")
  end
end
