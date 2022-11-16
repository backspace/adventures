defmodule AdventureRegistrations.PageControllerTest do
  use AdventureRegistrationsWeb.ConnCase

  test "GET /" do
    conn = get(build_conn(), "/")
    assert html_response(conn, 200) =~ "Clandestine Rendezvous"
  end
end
