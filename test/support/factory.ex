defmodule AdventureRegistrations.Factory do
  use ExMachina.Ecto, repo: AdventureRegistrations.Repo

  def user_factory do
    %AdventureRegistrationsWeb.User{
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
        crypted_password: Comeonin.Bcrypt.hashpwsalt("Xenogenesis")
      }
    )
  end

  def team_factory do
    %AdventureRegistrationsWeb.Team{}
  end

  def message_factory do
    %AdventureRegistrationsWeb.Message{
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
end
