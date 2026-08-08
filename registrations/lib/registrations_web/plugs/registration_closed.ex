defmodule RegistrationsWeb.Plugs.RegistrationClosed do
  @moduledoc """
  Hard-closes new self-service registration when `:registration_closed` is set —
  the sign-up (and pre-registration question) endpoints stop responding. Blocks:

    * `GET  /registration/new`    — the web sign-up form
    * `POST /registration`        — the web sign-up submit
    * `POST /powapi/registration` — the app sign-up
    * `POST /questions`           — the pre-registration "ask a question" form

  Everything else stays open: invitations (the pre-scheduled path), login,
  password reset, and detail edits (`GET/PATCH /registration/edit`). No-op when
  the flag is off.

  This is the *real* close. `:registration_warning` is a separate, softer flag
  that only shows a banner (see register_or_accept_invitation.html.eex) without
  blocking anything.

  Not covered: OAuth new-user creation via PowAssent — a negligible spam vector
  (it needs a real provider account). Close that separately if a run truly
  needs every account pre-registered.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2, json: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    # `== true` (not a bare get_env, which can be nil): the plug runs on every
    # browser request, and a strict `and` on a nil would crash them all.
    if Application.get_env(:registrations, :registration_closed) == true and blocked_path?(conn) do
      block(conn)
    else
      conn
    end
  end

  defp blocked_path?(%Plug.Conn{method: "GET", request_path: "/registration/new"}), do: true
  defp blocked_path?(%Plug.Conn{method: "POST", request_path: "/registration"}), do: true
  defp blocked_path?(%Plug.Conn{method: "POST", request_path: "/powapi/registration"}), do: true
  defp blocked_path?(%Plug.Conn{method: "POST", request_path: "/questions"}), do: true
  defp blocked_path?(_conn), do: false

  defp block(%Plug.Conn{request_path: "/powapi/registration"} = conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: %{code: "registration_closed", message: "Registration is closed."}})
    |> halt()
  end

  defp block(conn) do
    conn
    |> put_flash(:error, "Registration is closed.")
    |> redirect(to: "/")
    |> halt()
  end
end
