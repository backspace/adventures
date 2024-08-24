defmodule RegistrationsWeb.Pow.Routes do
  @moduledoc false
  use Pow.Phoenix.Routes

  # FIXME how does confirmation affect this?
  @impl true
  def after_sign_in_path(conn), do: RegistrationsWeb.Router.Helpers.user_path(conn, :edit)
end
