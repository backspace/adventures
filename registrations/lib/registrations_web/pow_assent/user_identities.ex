defmodule RegistrationsWeb.PowAssent.UserIdentities do
  use PowAssent.Ecto.UserIdentities.Context,
    repo: Registrations.Repo,
    user: RegistrationsWeb.User

  import Ecto.Query, only: [from: 2]

  def create_user(user_identity_params, user_params, user_id_params) do
    case pow_assent_create_user(user_identity_params, user_params, user_id_params) do
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
end
