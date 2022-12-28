ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(AdventureRegistrations.Repo, :manual)

defmodule Forge do
  use Blacksmith

  @save_one_function &Blacksmith.Config.save/1
  @save_all_function &Blacksmith.Config.save_all/1

  register(:user, %AdventureRegistrationsWeb.User{
    email: Sequence.next(:email, &"jh#{&1}@example.com")
  })

  register(:admin, [prototype: :user], admin: true)

  register(:octavia, [prototype: :user],
    email: "octavia.butler@example.com",
    crypted_password: Comeonin.Bcrypt.hashpwsalt("Xenogenesis")
  )

  register(:team, %AdventureRegistrationsWeb.Team{})

  register(:message, %AdventureRegistrationsWeb.Message{
    ready: true
  })

  register(:not_ready_message, [prototype: :message], ready: false)
end

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
