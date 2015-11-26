defmodule Cr2016site.PageController do
  use Cr2016site.Web, :controller

  def index(conn, _params) do
    users = Repo.all(Cr2016site.User)
    render conn, "index.html", users: users
  end
end
