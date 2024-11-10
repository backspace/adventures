defmodule RegistrationsWeb.UserSocket do
  use Phoenix.Socket

  alias RegistrationsWeb.PowAuthPlug

  channel "run:*", RegistrationsWeb.RunChannel

  def connect(%{"Authorization" => token}, socket) when is_binary(token) do
    config = Application.get_env(:registrations, :pow)

    conn =
      Plug.Conn.put_req_header(
        %Plug.Conn{secret_key_base: RegistrationsWeb.Endpoint.config(:secret_key_base)},
        "authorization",
        token
      )

    case PowAuthPlug.fetch(conn, config) do
      {_conn, %{id: user_id}} when not is_nil(user_id) ->
        {:ok, assign(socket, :user_id, user_id)}

      {_conn, nil} ->
        :error
    end
  end

  def connect(_params, _socket), do: :error

  def id(socket), do: "users_socket:#{socket.assigns.user_id}"
end
