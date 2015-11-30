# Adapted from Addict
# https://github.com/trenpixster/addict/blob/master/lib/addict/plugs/authenticated.ex

defmodule Cr2016site.Plugs.Admin do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _) do
    conn = fetch_session(conn)

    # FIXME share somehow with Session model?
    id = get_session(conn, :current_user)

    if id do
      user = Cr2016site.Repo.get(Cr2016site.User, id)

      if user && user.admin do
        conn
      else
        conn |> Phoenix.Controller.redirect(to: not_logged_in_url) |> halt
      end
    else
      conn |> Phoenix.Controller.redirect(to: not_logged_in_url) |> halt
    end
  end

  def not_logged_in_url do
    "/"
  end
end
