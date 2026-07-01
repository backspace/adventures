defmodule RegistrationsWeb.PowAssent.ReauthorizationPlugHandler do
  @moduledoc """
  Wraps PowAssent's default `ReauthorizationPlugHandler` and adds
  `DELETE /registration` (Pow's account-deletion endpoint) to the list
  of requests that should clear the stored reauthorization provider
  cookie.

  PowAssent's default only clears the cookie on `DELETE /session`
  (normal sign-out). If a user deletes their account, Pow removes the
  DB row and clears the Pow session — but the PowAssent cookie
  survives. The next time the browser visits /session/new, the
  Reauthorization plug sees the leftover cookie, redirects to the
  OAuth provider, and PowAssent's `create_user` upsert silently
  creates a brand-new account. This override closes that hole.
  """

  alias PowAssent.Phoenix.ReauthorizationPlugHandler, as: Default
  alias Pow.Phoenix.RegistrationController

  defdelegate reauthorize?(conn, config), to: Default
  defdelegate reauthorize(conn, provider, config), to: Default

  def clear_reauthorization?(conn, config) do
    Default.clear_reauthorization?(conn, config) or delete_registration?(conn)
  end

  defp delete_registration?(%{method: "DELETE"} = conn) do
    path = RegistrationController.routes(conn).path_for(conn, RegistrationController, :delete)
    conn.request_path == URI.parse(path).path
  end

  defp delete_registration?(_conn), do: false
end
