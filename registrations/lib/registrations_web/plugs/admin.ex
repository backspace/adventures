defmodule RegistrationsWeb.Plugs.Admin do
  @moduledoc false
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _) do
    conn = fetch_session(conn)
    user = conn.assigns[:current_user]

    if user && user.admin do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Who are you?")
      |> Phoenix.Controller.redirect(to: not_logged_in_url())
      |> halt()
    end
  end

  def not_logged_in_url do
    "/"
  end
end
