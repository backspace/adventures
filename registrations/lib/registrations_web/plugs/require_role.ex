defmodule RegistrationsWeb.Plugs.RequireRole do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    role = Keyword.fetch!(opts, :role)
    user = conn.assigns[:current_user]

    if user && Registrations.Accounts.has_role?(user, role) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{errors: [%{status: 403, title: "Forbidden", detail: "Role '#{role}' required"}]})
      |> halt()
    end
  end
end
