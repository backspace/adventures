{:ok, _} = Application.ensure_all_started(:ex_machina)

ExUnit.configure formatters: [JUnitFormatter, ExUnit.CLIFormatter]
ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(AdventureRegistrations.Repo, :manual)

# FIXME the duplication below can surely be extracted

defmodule AdventureRegistrations.ResetRequestConfirmation do
  use ExUnit.CaseTemplate

  setup do
    request_confirmation_setting = Application.get_env(:adventure_registrations, :request_confirmation)

    on_exit(fn ->
      Application.put_env(:adventure_registrations, :request_confirmation, request_confirmation_setting)
    end)

    :ok
  end
end

defmodule AdventureRegistrations.ResetRegistrationClosed do
  use ExUnit.CaseTemplate

  setup do
    registration_closed_setting = Application.get_env(:adventure_registrations, :registration_closed)

    on_exit(fn ->
      Application.put_env(:adventure_registrations, :registration_closed, registration_closed_setting)
    end)

    :ok
  end
end

defmodule AdventureRegistrations.SwooshHelper do
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

defmodule AdventureRegistrations.ClandestineRendezvous do
  use ExUnit.CaseTemplate

  setup do
    put_application_env_for_test(:adventure_registrations, :adventure, "clandestine-rendezvous")
  end

  defp put_application_env_for_test(app, key, value) do
    previous_value = Application.get_env(app, key)
    Application.put_env(app, key, value)
    on_exit(fn -> Application.put_env(app, key, previous_value) end)
  end
end
