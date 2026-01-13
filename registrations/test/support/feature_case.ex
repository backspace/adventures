defmodule RegistrationsWeb.FeatureCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use Wallaby.DSL

      import Ecto.Query, only: [from: 2]
      import Registrations.Factory

      alias Registrations.Repo

      @endpoint RegistrationsWeb.Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Registrations.Repo)

    unless tags[:async] do
      Sandbox.mode(Registrations.Repo, {:shared, self()})
    end

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Registrations.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)

    on_exit(fn -> Wallaby.end_session(session) end)

    {:ok, session: session, wallaby_metadata: metadata}
  end
end
