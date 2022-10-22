defmodule Cr2016site.PageControllerTest do
  use Cr2016siteWeb.ConnCase

  test "GET /" do
    conn = get(build_conn(), "/")
    assert html_response(conn, 200) =~ "Clandestine Rendezvous"
  end
end
