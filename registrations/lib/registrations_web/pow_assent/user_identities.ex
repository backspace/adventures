defmodule RegistrationsWeb.PowAssent.UserIdentities do
  @moduledoc false
  use PowAssent.Ecto.UserIdentities.Context,
    repo: Registrations.Repo,
    user: RegistrationsWeb.User

  def create_user(user_identity_params, user_params, user_id_params) do
    case pow_assent_create_user(user_identity_params, user_params, user_id_params) do
      {:ok, user} ->
        Registrations.Mailer.user_created(user)
        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
