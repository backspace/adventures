# Copied from https://hexdocs.pm/pow/1.0.38/api.html

defmodule RegistrationsWeb.PowAuthErrorHandler do
  use RegistrationsWeb, :controller
  alias Plug.Conn

  @spec call(Conn.t(), :not_authenticated) :: Conn.t()
  def call(conn, :not_authenticated) do
    conn
    |> put_status(401)
    |> json(%{error: %{code: 401, message: "Not authenticated"}})
  end
end
