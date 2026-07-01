defmodule RegistrationsWeb.Pow.Users do
  @moduledoc false
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

  def delete(user) do
    # Respect the result of pow_delete — a failed delete (e.g. blocked
    # by a foreign-key constraint) previously fell through silently
    # and still sent the "user deleted" admin email, making it look
    # like a successful deletion when the row was still in the DB.
    # Only email on actual success, and propagate the tuple so Pow's
    # controller can respond with the right flash/redirect.
    case pow_delete(user) do
      {:ok, deleted_user} = ok ->
        Registrations.Mailer.send_user_deletion(deleted_user)
        ok

      error ->
        error
    end
  end
end
