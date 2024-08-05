{:ok, _} = Application.ensure_all_started(:ex_machina)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Registrations.Repo, :manual)

defmodule Registrations.ApplicationEnvHelpers do
  use ExUnit.CaseTemplate

  def put_application_env_for_test(app, key, value) do
    previous_value = Application.get_env(app, key)
    Application.put_env(app, key, value)
    on_exit(fn -> Application.put_env(app, key, previous_value) end)
  end
end

defmodule Registrations.SwooshHelper do
  use ExUnit.CaseTemplate

  setup do
    Swoosh.Adapters.Local.Storage.Memory.delete_all()

    :ok
  end

  def sent_email do
    Swoosh.Adapters.Local.Storage.Memory.all()
  end

  def emails_sent? do
    length(sent_email()) > 0
  end
end

defmodule Registrations.ChromeHeadlessHelper do
  use ExUnit.CaseTemplate

  def additional_capabilities do
    [
      additional_capabilities: %{
        :"goog:chromeOptions" => %{
          "args" => [
            "--headless",
            "--disable-gpu",
            "--no-sandbox",
            "--disable-dev-shm-usage",
            "--disable-software-rasterizer"
          ]
        },
        browserName: "chrome"
      }
    ]
  end
end

defmodule Registrations.ClandestineRendezvous do
  use ExUnit.CaseTemplate

  setup do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :adventure,
      "clandestine-rendezvous"
    )
  end
end

defmodule Registrations.UnmnemonicDevices do
  use ExUnit.CaseTemplate

  setup do
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :adventure,
      "unmnemonic-devices"
    )
  end
end
