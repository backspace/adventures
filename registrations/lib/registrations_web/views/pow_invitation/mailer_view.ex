defmodule RegistrationsWeb.PowInvitation.MailerView do
  use RegistrationsWeb, :mailer_view

  def subject(:invitation, _assigns), do: "You've been invited"
end
