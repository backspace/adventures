defmodule RegistrationsWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  imports other functionality to make it easier
  to build and query models.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Ecto.Query, only: [from: 2]
      import Phoenix.ConnTest
      # Import conveniences for testing with connections
      import Plug.Conn
      import Registrations.Factory

      alias Registrations.Repo
      alias RegistrationsWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint RegistrationsWeb.Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Registrations.Repo)

    unless tags[:async] do
      Sandbox.mode(Registrations.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
