defmodule RegistrationsWeb.Plugs.LoginRequired do
  @moduledoc false
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _) do
    conn = fetch_session(conn)
    user = conn.assigns[:current_user]

    if user do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:info, "Please log in to edit your details")
      |> Phoenix.Controller.redirect(to: RegistrationsWeb.Router.Helpers.pow_session_path(conn, :new))
      |> halt()
    end
  end
end
