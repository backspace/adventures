defmodule RegistrationsWeb.Plugs.RequireRole do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    role = Keyword.fetch!(opts, :role)
    user = Pow.Plug.current_user(conn)

    if user && Registrations.Accounts.has_role?(user, role) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: %{code: "forbidden", detail: "Requires the '#{role}' role."}})
      |> halt()
    end
  end
end
