defmodule RegistrationsWeb.Plugs.RequireAnyRole do
  @moduledoc """
  Like `RequireRole`, but the user need only hold one of the listed roles
  to pass. Plus admins, who are implicitly allowed.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    roles = Keyword.fetch!(opts, :roles)
    user = Pow.Plug.current_user(conn)

    cond do
      is_nil(user) ->
        deny(conn, roles)

      user.admin ->
        conn

      Enum.any?(roles, &Registrations.Accounts.has_role?(user, &1)) ->
        conn

      true ->
        deny(conn, roles)
    end
  end

  defp deny(conn, roles) do
    conn
    |> put_status(:forbidden)
    |> Phoenix.Controller.json(%{
      error: %{
        code: "forbidden",
        detail: "Requires one of: #{Enum.join(roles, ", ")}."
      }
    })
    |> halt()
  end
end
