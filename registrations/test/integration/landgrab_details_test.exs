defmodule Registrations.Integration.LandgrabDetails do
  @moduledoc """
  The details form under the landgrab adventure, where the accessibility-tag
  chips are shown. Covers the interaction between the confirmation
  requirement (a required `attending` answer) and the tag checkboxes: a
  failed submit must re-render with the boxes the participant just checked,
  not silently revert them to the last-saved values.
  """
  use RegistrationsWeb.FeatureCase
  use Registrations.SwooshHelper
  use Registrations.SetAdventure, adventure: "landgrab"

  alias Registrations.Pages.Details
  alias Registrations.Pages.Details.Attending.Error
  alias Registrations.Pages.Login
  alias Registrations.Pages.Nav

  test "a checked accessibility tag survives a submit rejected for a blank attending answer",
       %{session: session} do
    # Confirmation on → `attending` is required, so a submit that leaves it
    # blank fails the changeset and re-renders the form. This is exactly the
    # dev-server setup where the bug bit.
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :request_confirmation,
      true
    )

    insert(:user, email: "takver@example.com")

    visit(session, "/")
    Login.login_as(session, "takver@example.com", "Xenogenesis")
    visit(session, "/details")

    assert Details.Attending.present?(session), "Expected the attending question under landgrab"
    refute Details.accessibility_tags().checked?(session, "stairs"),
           "Expected the stairs tag to start unchecked"

    # Check a tag but leave the required attending answer blank, then submit.
    Details.accessibility_tags().check(session, "stairs")
    Details.submit(session)

    # The submit is rejected (attending is required)...
    Error.assert_present(session, "Expected an error about the blank attending answer")

    # ...and the tag the participant just checked is preserved on the
    # re-rendered form rather than reverting to the last-saved (empty) value.
    Details.accessibility_tags().assert_checked(
      session,
      "stairs",
      "Expected the checked accessibility tag to survive the rejected submit"
    )

    # Answering attending now lets the whole thing — tag included — save.
    Details.Attending.yes(session)
    Details.submit(session)

    Nav.assert_info_text(session, "Your details were saved")
    Details.accessibility_tags().assert_checked(session, "stairs",
      "Expected the tag to persist after a successful save")
  end
end
