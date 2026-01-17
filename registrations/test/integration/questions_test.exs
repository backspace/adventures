defmodule Registrations.ClandestineRendezvous.Integration.Questions do
  @moduledoc false
  use RegistrationsWeb.FeatureCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "clandestine-rendezvous"

  alias Registrations.Pages.Home
  alias Registrations.Pages.Nav

  test "submitting a question", %{session: session} do
    visit(session, "/")

    Home.fill_name(session, "Lucy Parsons")
    Home.fill_email(session, "lucy@example.com")
    Home.fill_subject(session, "A Word to Tramps")

    Home.fill_question(
      session,
      "Can you not see that it is the industrial system and not the \"boss\" which must be changed?"
    )

    Home.submit_question(session)

    assert Nav.info_text(session, "Your question has been submitted.") ==
             "Your question has been submitted."

    wait_for_emails([sent_email])
    assert sent_email.to == [{"", "b@events.chromatin.ca"}]
    assert sent_email.from == {"", "b@events.chromatin.ca"}

    assert sent_email.subject ==
             "Question from Lucy Parsons <lucy@example.com>: A Word to Tramps"

    assert sent_email.text_body ==
             "Can you not see that it is the industrial system and not the \"boss\" which must be changed?"
  end
end

defmodule Registrations.UnmnemonicDevices.Integration.Questions do
  @moduledoc false
  use RegistrationsWeb.FeatureCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "unmnemonic-devices"

  alias Registrations.Pages.Home
  alias Registrations.Pages.Nav

  test "submitting a question", %{session: session} do
    visit(session, "/")

    Home.fill_name(session, "Lucy Parsons")
    Home.fill_email(session, "lucy@example.com")
    Home.fill_subject(session, "A Word to Tramps")

    Home.fill_question(
      session,
      "Can you not see that it is the industrial system and not the \"boss\" which must be changed?"
    )

    Home.submit_question(session)

    assert Nav.info_text(session, "Your question has been submitted.") ==
             "Your question has been submitted."

    wait_for_emails([sent_email])
    assert sent_email.to == [{"", "knut@chromatin.ca"}]
    assert sent_email.from == {"", "knut@chromatin.ca"}

    assert sent_email.subject ==
             "Question from Lucy Parsons <lucy@example.com>: A Word to Tramps"

    assert sent_email.text_body ==
             "Can you not see that it is the industrial system and not the \"boss\" which must be changed?"
  end
end
