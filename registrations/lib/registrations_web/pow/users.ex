defmodule RegistrationsWeb.Pow.Users do
  use Pow.Ecto.Context,
    repo: Registrations.Repo,
    user: RegistrationsWeb.User

  def create(params) do
    case pow_create(params) do
      {:ok, user} ->
        Registrations.Mailer.user_created(user)
        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete(params) do
    pow_delete(params)
    Registrations.Mailer.send_user_deletion(params)
  end
end
