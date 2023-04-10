defmodule AdventureRegistrationsWeb.ConnCase do
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

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest

      alias AdventureRegistrations.Repo
      import Ecto.Query, only: [from: 2]

      alias AdventureRegistrationsWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint AdventureRegistrationsWeb.Endpoint

      import AdventureRegistrations.Factory
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(AdventureRegistrations.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(AdventureRegistrations.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end