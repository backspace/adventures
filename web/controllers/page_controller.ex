defmodule Cr2016site.PageController do
  use Cr2016site.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
