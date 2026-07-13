defmodule RegistrationsWeb.Plugs.ReloadUser do
  @moduledoc """
  Pow's API token store caches the user struct at sign-in, so fields
  like `team_id` go stale when the database changes under a live
  session (rehearsal copies, team rebuilds). Controllers then act on
  a team that no longer exists — a 500 at the first FK it touches.
  Replace the cached struct with a fresh read so controllers can
  trust what they're given; a user deleted since sign-in becomes 401.

  Must run after `Pow.Plug.RequireAuthenticated`.
  """
  import Plug.Conn

  alias Registrations.Repo
  alias RegistrationsWeb.User

  def init(opts), do: opts

  def call(conn, _opts) do
    case Pow.Plug.current_user(conn) do
      nil ->
        conn

      user ->
        case Repo.get(User, user.id) do
          nil ->
            conn
            |> put_status(:unauthorized)
            |> Phoenix.Controller.json(%{error: %{code: "unauthorized", detail: "Account no longer exists."}})
            |> halt()

          fresh ->
            Pow.Plug.assign_current_user(conn, fresh, Pow.Plug.fetch_config(conn))
        end
    end
  end
end
