{:ok, _} = Application.ensure_all_started(:ex_machina)
{:ok, _} = Application.ensure_all_started(:wallaby)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Registrations.Repo, :manual)

defmodule Registrations.ApplicationEnvHelpers do
  @moduledoc false
  use ExUnit.CaseTemplate

  def put_application_env_for_test(app, key, value) do
    previous_value = Application.get_env(app, key)
    Application.put_env(app, key, value)
    on_exit(fn -> Application.put_env(app, key, previous_value) end)
  end
end

defmodule Registrations.WindowHelpers do
  @moduledoc false
  alias Wallaby.Browser

  def set_window_to_show_account(session) do
    Browser.resize_window(session, 720, 450)
  end
end

defmodule Registrations.SwooshHelper do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Swoosh.Adapters.Local.Storage.Memory

  setup do
    Memory.delete_all()

    :ok
  end

  def sent_email do
    Memory.all()
  end

  def emails_sent? do
    length(sent_email()) > 0
  end
end

defmodule Registrations.SetAdventure do
  @moduledoc false
  use ExUnit.CaseTemplate

  defmacro __using__(opts) do
    adventure = Keyword.fetch!(opts, :adventure)

    quote do
      setup do
        Registrations.ApplicationEnvHelpers.put_application_env_for_test(
          :registrations,
          :adventure,
          unquote(adventure)
        )
      end
    end
  end
end
