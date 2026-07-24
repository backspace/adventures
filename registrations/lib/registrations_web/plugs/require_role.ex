defmodule RegistrationsWeb.Plugs.RequireRole do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    # `role:` requires that one role; `any_of:` allows any role in the list
    # (e.g. a route open to both authors and supervisors).
    roles =
      case Keyword.fetch(opts, :any_of) do
        {:ok, list} -> list
        :error -> [Keyword.fetch!(opts, :role)]
      end

    user = Pow.Plug.current_user(conn)

    if user && Enum.any?(roles, &Registrations.Accounts.has_role?(user, &1)) do
      conn
    else
      detail =
        case roles do
          [one] -> "Requires the '#{one}' role."
          many -> "Requires one of these roles: #{Enum.join(many, ", ")}."
        end

      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: %{code: "forbidden", detail: detail}})
      |> halt()
    end
  end
end
