defmodule Cr2016site.IntegrationTest do
  use Cr2016site.ConnCase

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session

  test "GET /" do
    Forge.saved_user email: "francine.pascal@example.com"

    navigate_to "/"
    assert page_source =~ "Clandestine Rendezvous"

    assert page_source =~ "francine.pascal@example.com"
  end
end
