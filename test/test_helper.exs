ExUnit.start

Mix.Task.run "ecto.create", ["--quiet"]
Mix.Task.run "ecto.migrate", ["--quiet"]
Ecto.Adapters.SQL.begin_test_transaction(Cr2016site.Repo)

defmodule Forge do
  use Blacksmith

  @save_one_function &Blacksmith.Config.save/1
  @save_all_function &Blacksmith.Config.save_all/1

  register :user, %Cr2016site.User{
    email: Sequence.next(:email, &"jh#{&1}@example.com")
  }

  register :admin, [prototype: :user], admin: true

  register :message, %Cr2016site.Message{
    ready: true
  }
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
