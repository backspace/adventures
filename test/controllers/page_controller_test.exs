defmodule Cr2016site.PageControllerTest do
  use Cr2016site.ConnCase

  test "GET /" do
    conn = get conn(), "/"
    assert html_response(conn, 200) =~ "Clandestine Rendezvous"
  end
end
