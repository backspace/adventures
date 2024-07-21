defmodule RegistrationsWeb.Pow.Messages do
  use Pow.Phoenix.Messages
  use Pow.Extension.Phoenix.Messages, extensions: [PowResetPassword, PowAssent]

  def user_has_been_created(_conn), do: "Your account was created"

  def signed_in(_conn), do: "Logged in"
  def signed_out(_conn), do: "Logged out"
end
