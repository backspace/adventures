defmodule RegistrationsWeb.Api.DeviceTokenController do
  @moduledoc """
  The app POSTs its FCM token here after sign-in (and again whenever
  FCM rotates it). Upsert semantics live in
  `Registrations.Landgrab.register_device_token/3`.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab

  def create(conn, %{"token" => token, "platform" => platform}) do
    user = Pow.Plug.current_user(conn)

    case Landgrab.register_device_token(user.id, token, platform) do
      {:ok, _device_token} ->
        json(conn, %{ok: true})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{errors: %{detail: "token and platform are required"}})
  end
end
