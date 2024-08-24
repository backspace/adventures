defmodule Registrations.Integration.Messages do
  use RegistrationsWeb.ConnCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "clandestine-rendezvous"

  alias Registrations.Pages.Login
  alias Registrations.Pages.Register
  alias Registrations.Pages.Messages
  alias Registrations.Pages.Nav

  use Hound.Helpers
  hound_session(Registrations.ChromeHeadlessHelper.additional_capabilities())

  test "a message is sent to all registrants with their team information summarised" do
    insert(:admin,
      email: "admin@example.com",
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("admin")
    )

    insert(:user,
      email: "user@example.com",
      team_emails: "teammate@example.com",
      proposed_team_name: "Jorts"
    )

    insert(:user,
      email: "teammate@example.com",
      team_emails: "user@example.com",
      proposed_team_name: "Jants"
    )

    insert(:user, email: "empty@example.com")

    navigate_to("/")

    Login.login_as("admin@example.com", "admin")
    Nav.edit_messages()

    Messages.new_message()

    Messages.fill_subject("A Subject!")
    Messages.fill_content("This is the content.")
    Messages.fill_postmarked_at("2010-01-01")
    Messages.check_ready()
    Messages.save()

    Messages.send()
    Messages.dismiss_alert()

    assert Nav.info_text() == "Message was sent"

    [empty_email, _, email, _] = Registrations.SwooshHelper.sent_email()
    assert email.to == [{"", "user@example.com"}]
    assert email.from == {"", "b@events.chromatin.ca"}
    assert email.subject == "[rendezvous] A Subject!"

    text = email.text_body
    assert String.contains?(text, "Jorts")
    assert String.contains?(text, "Jants")

    assert String.contains?(empty_email.text_body, "You haven’t filled in any details!")
  end

  test "a message can be sent to just the logged-in user" do
    insert(:admin,
      email: "admin@example.com",
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("admin")
    )

    insert(:user,
      email: "user@example.com",
      team_emails: "teammate@example.com",
      proposed_team_name: "Jorts"
    )

    insert(:user,
      email: "teammate@example.com",
      team_emails: "user@example.com",
      proposed_team_name: "Jants"
    )

    insert(:user, email: "empty@example.com")

    navigate_to("/")

    Login.login_as("admin@example.com", "admin")
    Nav.edit_messages()

    Messages.new_message()

    Messages.fill_subject("A Subject!")
    Messages.fill_content("This is the content.")
    Messages.fill_postmarked_at("2010-01-01")
    Messages.check_ready()
    Messages.save()

    Messages.send_to_me()

    assert Nav.info_text() == "Message was sent"

    [email] = Registrations.SwooshHelper.sent_email()
    assert email.to == [{"", "admin@example.com"}]
    assert email.from == {"", "b@events.chromatin.ca"}
    assert email.subject == "[rendezvous] A Subject!"
  end

  test "message sender name/address can be overridden" do
    insert(:admin,
      email: "admin@example.com",
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("admin")
    )

    navigate_to("/")

    Login.login_as("admin@example.com", "admin")
    Nav.edit_messages()

    Messages.new_message()

    Messages.fill_subject("A Subject!")
    Messages.fill_content("This is the content.")

    Messages.fill_from_name("Knut")
    Messages.fill_from_address("knut@example.com")
    Messages.fill_postmarked_at("2010-01-01")

    Messages.check_ready()
    Messages.save()

    Messages.send()
    Messages.dismiss_alert()

    assert Nav.info_text() == "Message was sent"

    [email] = Registrations.SwooshHelper.sent_email()
    assert email.from == {"Knut", "knut@example.com"}
  end

  test "a message with show team enabled shows the actual team information instead of their details" do
    insert(:admin,
      email: "admin@example.com",
      password_hash: Pow.Ecto.Schema.Password.pbkdf2_hash("admin")
    )

    team =
      insert(:team,
        name: "True team name",
        risk_aversion: 1
      )

    insert(:user,
      email: "user-with-team@example.com",
      team_emails: "teammate@example.com",
      proposed_team_name: "Ignored team name",
      team_id: team.id
    )

    insert(:user, email: "teammate@example.com", team_id: team.id)

    insert(:user, email: "teamless-user@example.com")

    navigate_to("/")

    Login.login_as("admin@example.com", "admin")
    Nav.edit_messages()

    Messages.new_message()

    Messages.fill_subject("A Subject!")
    Messages.fill_content("ya")
    Messages.fill_postmarked_at("2010-01-01")
    Messages.check_ready()
    Messages.check_show_team()
    Messages.save()

    Messages.send()
    Messages.dismiss_alert()

    assert Nav.info_text() == "Message was sent"

    sent_emails = Registrations.SwooshHelper.sent_email()

    has_team_email =
      Enum.find(sent_emails, fn email ->
        email.to == [{"", "user-with-team@example.com"}]
      end)

    has_no_team_email =
      Enum.find(sent_emails, fn email ->
        email.to == [{"", "teamless-user@example.com"}]
      end)

    assert has_team_email
    assert String.contains?(has_team_email.text_body, "True team name")
    assert String.contains?(has_team_email.text_body, "Go easy on me")

    assert String.contains?(
             has_team_email.text_body,
             "teammate@example.com, user-with-team@example.com"
           )

    assert has_no_team_email
    assert String.contains?(has_no_team_email.text_body, "You have no team assigned!")
  end

  test "the backlog of existing messages is sent to a new registrant after the welcome" do
    insert(:message,
      subject: "Subject one",
      content: "Content one",
      from_name: "Yes",
      from_address: "yes@example.com"
    )

    insert(:message, subject: "Subject two", content: "Content two")
    insert(:not_ready_message, subject: "Not ready", content: "Not ready")

    navigate_to("/")
    Nav.register_link().click()

    Register.fill_email("registerer@example.com")
    Register.fill_password("abcdefghi")
    Register.fill_password_confirmation("abcdefghi")
    Register.submit()

    [_admin, _welcome, backlog_email] = Registrations.SwooshHelper.sent_email()

    assert backlog_email.to == [{"", "registerer@example.com"}]
    assert backlog_email.from == {"", "b@events.chromatin.ca"}

    assert backlog_email.subject == "[rendezvous] Messages sent before you registered"

    text = backlog_email.text_body
    assert String.contains?(text, "These messages were sent before you registered.")

    assert String.contains?(text, "Subject one")
    assert String.contains?(text, "From: Yes <yes@example.com>")
    assert String.contains?(text, "Content one")

    assert String.contains?(text, "Subject two")
    assert String.contains?(text, "Content two")

    refute String.contains?(text, "Not ready")
  end
end
