defmodule AdventureRegistrations.PageControllerTest do
  use AdventureRegistrationsWeb.ConnCase
  use AdventureRegistrations.ClandestineRendezvous

  test "GET /" do
    conn = get(build_conn(), "/")
    assert html_response(conn, 200) =~ "Clandestine Rendezvous"
  end
end
