defmodule Cr2016site.IntegrationTest do
  use Cr2016site.ConnCase

  # Import Hound helpers
  use Hound.Helpers

  # Start a Hound session
  hound_session

  test "GET /" do
    navigate_to "/"
    assert page_source =~ "Clandestine Rendezvous"
  end
end
