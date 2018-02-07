defmodule Cr2016site.Integration.Messages do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper

  alias Cr2016site.Pages.Login
  alias Cr2016site.Pages.Register
  alias Cr2016site.Pages.Messages
  alias Cr2016site.Pages.Nav

  use Hound.Helpers
  hound_session()

  test "a message is sent to all registrants with their team information summarised" do
    Forge.saved_admin email: "admin@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("admin")
    Forge.saved_user email: "user@example.com", team_emails: "teammate@example.com", proposed_team_name: "Jorts"
    Forge.saved_user email: "teammate@example.com", team_emails: "user@example.com", proposed_team_name: "Jants"
    Forge.saved_user email: "empty@example.com"

    navigate_to "/"

    Login.login_as "admin@example.com", "admin"
    Nav.edit_messages

    Messages.new_message

    Messages.fill_subject "A Subject!"
    Messages.fill_content "This is the content."
    Messages.check_ready
    Messages.save

    Messages.send

    assert Nav.info_text == "Message was sent"

    [_, email, _, %{"text" => empty_email_text}] = Cr2016site.MailgunHelper.sent_email
    assert email["to"] == "user@example.com"
    assert email["from"] == Application.get_env(:cr2016site, :email_address)
    assert email["subject"] == "[rendezvous] A Subject!"

    text = email["text"]
    assert String.contains?(text, "Jorts")
    assert String.contains?(text, "Jants")

    assert String.contains?(empty_email_text, "You haven’t filled in any details!")
  end

  test "a message with show team enabled shows the actual team information instead of their details" do
    Forge.saved_admin email: "admin@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("admin")
    {_, team_member_1} = Forge.saved_user email: "user-with-team@example.com", team_emails: "teammate@example.com", proposed_team_name: "Ignored team name"
    {_, team_member_2} = Forge.saved_user email: "teammate@example.com"
    Forge.saved_user email: "teamless-user@example.com"

    Forge.saved_team name: "True team name", risk_aversion: 1, user_ids: [team_member_1.id, team_member_2.id]

    navigate_to "/"

    Login.login_as "admin@example.com", "admin"
    Nav.edit_messages

    Messages.new_message

    Messages.fill_subject "A Subject!"
    Messages.fill_content "ya"
    Messages.check_ready
    Messages.check_show_team
    Messages.save

    Messages.send

    [_, has_team_email, _, has_no_team_email] = Cr2016site.MailgunHelper.sent_email

    assert has_team_email["to"] == "user-with-team@example.com"
    assert String.contains?(has_team_email["text"], "True team name")
    assert String.contains?(has_team_email["text"], "Go easy on me")

    assert has_no_team_email["to"] == "teamless-user@example.com"
    assert String.contains?(has_no_team_email["text"], "You have no team assigned!")
  end

  test "the backlog of existing messages is sent to a new registrant after the welcome" do
    Forge.saved_message subject: "Subject one", content: "Content one"
    Forge.saved_message subject: "Subject two", content: "Content two"
    Forge.saved_not_ready_message subject: "Not ready", content: "Not ready"

    navigate_to "/"
    Nav.register_link.click

    Register.fill_email "registerer@example.com"
    Register.fill_password "abcdefghi"
    Register.submit

    [_admin, _welcome, backlog_email] = Cr2016site.MailgunHelper.sent_email

    assert backlog_email["to"] == "registerer@example.com"
    assert backlog_email["from"] == Application.get_env(:cr2016site, :email_address)

    assert backlog_email["subject"] == "[rendezvous] Messages sent before you registered"

    text = backlog_email["text"]
    assert String.contains?(text, "These messages were sent before you registered.")

    assert String.contains?(text, "Subject one")
    assert String.contains?(text, "Content one")

    assert String.contains?(text, "Subject two")
    assert String.contains?(text, "Content two")

    refute String.contains?(text, "Not ready")
  end
end
