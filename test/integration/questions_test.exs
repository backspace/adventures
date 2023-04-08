defmodule AdventureRegistrations.ClandestineRendezvous.Integration.Questions do
  use AdventureRegistrationsWeb.ConnCase
  use AdventureRegistrations.SwooshHelper
  use AdventureRegistrations.ClandestineRendezvous

  alias AdventureRegistrations.Pages.Home
  alias AdventureRegistrations.Pages.Nav

  use Hound.Helpers

  hound_session()

  test "registering" do
    navigate_to("/")

    Home.fill_name("Lucy Parsons")
    Home.fill_email("lucy@example.com")
    Home.fill_subject("A Word to Tramps")

    Home.fill_question(
      "Can you not see that it is the industrial system and not the \"boss\" which must be changed?"
    )

    Home.submit_question()

    assert Nav.info_text() == "Your question has been submitted."

    [sent_email] = AdventureRegistrations.SwooshHelper.sent_email()
    assert sent_email.to == [{"", "b@events.chromatin.ca"}]
    assert sent_email.from == {"", "b@events.chromatin.ca"}

    assert sent_email.subject ==
             "Question from Lucy Parsons <lucy@example.com>: A Word to Tramps"

    assert sent_email.text_body ==
             "Can you not see that it is the industrial system and not the \"boss\" which must be changed?"
  end
end

defmodule AdventureRegistrations.UnmnemonicDevices.Integration.Questions do
  use AdventureRegistrationsWeb.ConnCase
  use AdventureRegistrations.SwooshHelper
  use AdventureRegistrations.UnmnemonicDevices

  alias AdventureRegistrations.Pages.Home
  alias AdventureRegistrations.Pages.Nav

  use Hound.Helpers

  hound_session()

  test "registering" do
    navigate_to("/")

    Home.fill_name("Lucy Parsons")
    Home.fill_email("lucy@example.com")
    Home.fill_subject("A Word to Tramps")

    Home.fill_question(
      "Can you not see that it is the industrial system and not the \"boss\" which must be changed?"
    )

    Home.submit_question()

    assert Nav.info_text() == "Your question has been submitted."

    [sent_email] = AdventureRegistrations.SwooshHelper.sent_email()
    assert sent_email.to == [{"", "b@events.chromatin.ca"}]
    assert sent_email.from == {"", "b@events.chromatin.ca"}

    assert sent_email.subject ==
             "Question from Lucy Parsons <lucy@example.com>: A Word to Tramps"

    assert sent_email.text_body ==
             "Can you not see that it is the industrial system and not the \"boss\" which must be changed?"
  end
end
