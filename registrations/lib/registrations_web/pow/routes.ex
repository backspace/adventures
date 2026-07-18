defmodule RegistrationsWeb.Pow.Routes do
  @moduledoc false
  use Pow.Phoenix.Routes

  # FIXME how does confirmation affect this?
  @impl true
  def after_sign_in_path(conn), do: RegistrationsWeb.Router.Helpers.user_path(conn, :edit)

  # Redirect to the landing page after account deletion rather than
  # Pow's default (`session_path(:new)` — the login page). The default
  # is what triggers the silent re-register loop for OAuth users:
  # PowAssent's Reauthorization plug watches for /session/new, sees
  # the still-present provider cookie, and redirects to Google — which
  # creates a fresh account via the OAuth callback.
  #
  # The `account_deleted` marker lets the app's details WebView tell a real
  # deletion apart from an ordinary "Home" navigation (both hit the root).
  @impl true
  def after_user_deleted_path(_conn), do: "/?account_deleted=1"
end
