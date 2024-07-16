defmodule RegistrationsWeb.Pow.Users do
  use Pow.Ecto.Context,
    repo: Registrations.Repo,
    user: RegistrationsWeb.User

  def delete(params) do
    pow_delete(params)
    Registrations.Mailer.send_user_deletion(params)
  end
end
