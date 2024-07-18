defmodule RegistrationsWeb.PowResetPassword.MailerView do
  use RegistrationsWeb, :mailer_view

  def subject(:reset_password, _assigns), do: "Reset password link"
end
