ExUnit.start

Ecto.Adapters.SQL.Sandbox.mode(Cr2016site.Repo, :manual)

defmodule Forge do
  use Blacksmith

  @save_one_function &Blacksmith.Config.save/1
  @save_all_function &Blacksmith.Config.save_all/1

  register :user, %Cr2016site.User{
    email: Sequence.next(:email, &"jh#{&1}@example.com")
  }

  register :admin, [prototype: :user], admin: true

  register :octavia, [prototype: :user],
    email: "octavia.butler@example.com",
    crypted_password: Comeonin.Bcrypt.hashpwsalt("Xenogenesis")

  register :team, %Cr2016site.Team{}

  register :message, %Cr2016site.Message{
    ready: true
  }

  register :not_ready_message, [prototype: :message], ready: false
end

# FIXME the duplication below can surely be extracted

defmodule Cr2016site.ResetRequestConfirmation do
  use ExUnit.CaseTemplate

  setup do
    request_confirmation_setting = Application.get_env(:cr2016site, :request_confirmation)

    on_exit fn ->
      Application.put_env(:cr2016site, :request_confirmation, request_confirmation_setting)
    end

    :ok
  end
end

defmodule Cr2016site.ResetRegistrationClosed do
  use ExUnit.CaseTemplate

  setup do
    registration_closed_setting = Application.get_env(:cr2016site, :registration_closed)

    on_exit fn ->
      Application.put_env(:cr2016site, :registration_closed, registration_closed_setting)
    end

    :ok
  end
end

defmodule Cr2016site.MailgunHelper do
  use ExUnit.CaseTemplate

  setup do
    File.rm Application.get_env(:cr2016site, :mailgun_test_file_path)

    on_exit fn ->
      File.rm Application.get_env(:cr2016site, :mailgun_test_file_path)
    end

    :ok
  end

  def sent_email do
    mail_text = File.read! Application.get_env(:cr2016site, :mailgun_test_file_path)
    Poison.Parser.parse! mail_text
  end

  def emails_sent? do
    File.exists? Application.get_env(:cr2016site, :mailgun_test_file_path)
  end
end
