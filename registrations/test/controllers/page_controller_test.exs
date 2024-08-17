defmodule Registrations.PageControllerTest do
  use RegistrationsWeb.ConnCase
  use Registrations.SetAdventure, adventure: "clandestine-rendezvous"

  test "GET /" do
    conn = get(build_conn(), "/")
    assert html_response(conn, 200) =~ "Clandestine Rendezvous"
  end
end
