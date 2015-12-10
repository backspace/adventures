defmodule Cr2016site.Integration.Questions do
  use Cr2016site.ConnCase
  use Cr2016site.MailgunHelper

  alias Cr2016site.Pages.Home
  alias Cr2016site.Pages.Nav

  use Hound.Helpers

  hound_session

  test "registering" do
    navigate_to "/"

    Home.fill_name "Lucy Parsons"
    Home.fill_email "lucy@example.com"
    Home.fill_subject "A Word to Tramps"
    Home.fill_question "Can you not see that it is the industrial system and not the \"boss\" which must be changed?"
    Home.submit_question

    assert Nav.info_text == "Your question has been submitted."

    sent_email = Cr2016site.MailgunHelper.sent_email
    assert sent_email["to"] == "b@events.chromatin.ca"
    assert sent_email["from"] == "b@rendezvous.chromatin.ca"
    assert sent_email["subject"] == "Question from Lucy Parsons <lucy@example.com>: A Word to Tramps"
    assert sent_email["text"] == "Can you not see that it is the industrial system and not the \"boss\" which must be changed?"
  end
end
