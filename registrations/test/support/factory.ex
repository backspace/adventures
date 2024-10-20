defmodule Registrations.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: Registrations.Repo

  alias Pow.Ecto.Schema.Password

  def user_factory do
    %RegistrationsWeb.User{
      email: sequence(:email, &"jh#{&1}@example.com"),
      password_hash: Password.pbkdf2_hash("Xenogenesis")
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
        password_hash: Password.pbkdf2_hash("Xenogenesis")
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

  def answer_factory do
    %Registrations.Waydowntown.Answer{}
  end

  def region_factory do
    %Registrations.Waydowntown.Region{}
  end

  def run_factory do
    %Registrations.Waydowntown.Run{}
  end

  def specification_factory do
    %Registrations.Waydowntown.Specification{}
  end

  def submission_factory do
    %Registrations.Waydowntown.Submission{}
  end
end
