defmodule RegistrationsWeb.Pow.Users do
  use Pow.Ecto.Context,
    repo: Registrations.Repo,
    user: RegistrationsWeb.User

  import Ecto.Query, only: [from: 2]

  def create(params) do
    case pow_create(params) do
      {:ok, user} ->
        messages =
          Registrations.Repo.all(
            from(m in RegistrationsWeb.Message,
              where: m.ready == true,
              select: m,
              order_by: :postmarked_at
            )
          )

        unless Enum.empty?(messages) do
          Registrations.Mailer.send_backlog(messages, user)
        end

        Registrations.Mailer.send_welcome_email(user.email)
        Registrations.Mailer.send_registration(user)
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
