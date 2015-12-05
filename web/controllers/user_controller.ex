defmodule Cr2016site.UserController do
  use Cr2016site.Web, :controller

  plug Cr2016site.Plugs.Admin when action in [:index]

  def index(conn, _params) do
    users = Repo.all(Cr2016site.User)
    render conn, "index.html", users: users
  end

  def edit(conn, _) do
    render conn, "edit.html"
  end
end
