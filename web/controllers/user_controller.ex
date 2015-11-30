defmodule Cr2016site.UserController do
  use Cr2016site.Web, :controller

  plug Cr2016site.Plugs.Admin

  def index(conn, _params) do
    users = Repo.all(Cr2016site.User)
    render conn, "index.html", users: users
  end
end
