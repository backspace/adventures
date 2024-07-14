defmodule RegistrationsWeb.Pow.Routes do
  use Pow.Phoenix.Routes

  @impl true
  def after_sign_in_path(conn), do: RegistrationsWeb.Router.Helpers.user_path(conn, :edit)
end
