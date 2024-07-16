defmodule RegistrationsWeb.PowEmailConfirmation.MailerView do
  use RegistrationsWeb, :mailer_view

  def subject(:email_confirmation, _assigns), do: "Confirm your email address"
end
