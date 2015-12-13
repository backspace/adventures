defmodule Cr2016site.Integration.Messages do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper

  alias Cr2016site.Pages.Login
  alias Cr2016site.Pages.Messages
  alias Cr2016site.Pages.Nav

  use Hound.Helpers
  hound_session

  test "a message is sent to all registrants" do
    Forge.saved_admin email: "admin@example.com", crypted_password: Comeonin.Bcrypt.hashpwsalt("admin")
    Forge.saved_user email: "user@example.com"

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

    [_, email] = Cr2016site.MailgunHelper.sent_email
    assert email["to"] == "user@example.com"
    assert email["from"] == "b@events.chromatin.ca"
    assert email["subject"] == "[rendezvous] A Subject!"
  end

end