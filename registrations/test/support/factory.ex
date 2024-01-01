defmodule Registrations.Factory do
  use ExMachina.Ecto, repo: Registrations.Repo

  def user_factory do
    %RegistrationsWeb.User{
      email: sequence(:email, &"jh#{&1}@example.com")
    }
  end

  def admin_factory do
    struct!(
      user_factory(),
      %{
        admin: true
      }
    )
  end

  def octavia_factory do
    struct!(
      user_factory(),
      %{
        email: "octavia.butler@example.com",
        crypted_password: Bcrypt.hash_pwd_salt("Xenogenesis")
      }
    )
  end

  def team_factory do
    %RegistrationsWeb.Team{}
  end

  def message_factory do
    %RegistrationsWeb.Message{
      ready: true
    }
  end

  def not_ready_message_factory do
    struct!(
      message_factory(),
      %{
        ready: false
      }
    )
  end

  def unmnemonic_devices_settings_factory do
    %RegistrationsWeb.UnmnemonicDevices.Settings{}
  end
end
