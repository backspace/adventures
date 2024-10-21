defmodule RegistrationsWeb.Plugs.AdminAPI do
  @moduledoc false
  import Plug.Conn

  def init(options), do: options

  def call(conn, _) do
    user = conn.assigns[:current_user]

    if user && user.admin do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{errors: [%{status: 403, title: "Forbidden", detail: "Admin access required"}]})
      |> halt()
    end
  end
end
