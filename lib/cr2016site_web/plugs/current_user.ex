# Adapted from Addict
# https://github.com/trenpixster/addict/blob/master/lib/addict/plugs/authenticated.ex

defmodule Cr2016siteWeb.Plugs.CurrentUser do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _) do
    conn = fetch_session(conn)

    id = get_session(conn, :current_user)

    if id do
      user = Cr2016site.Repo.get(Cr2016siteWeb.User, id)
      assign(conn, :current_user_object, user)
    else
      conn
    end
  end
end
