defmodule Registrations.Repo.Migrations.CascadeUserIdentityDelete do
  @moduledoc """
  The original `user_identities` migration set the `user_id` FK to
  `on_delete: :nothing`, which meant Postgres refused to delete a
  `users` row while any `user_identities` row referenced it. Combined
  with `RegistrationsWeb.Pow.Users.delete/1` discarding the resulting
  `{:error, changeset}`, "delete your account" LOOKED like it worked
  (admin got the email) but neither row was actually deleted.

  Switching to `:delete_all` lets Postgres cascade the identity rows
  when the parent user is deleted, which is what you want for an
  identity-provider link table.
  """
  use Ecto.Migration

  def change do
    alter table(:user_identities) do
      modify :user_id,
             references("users", on_delete: :delete_all, type: :binary_id),
             from: references("users", on_delete: :nothing, type: :binary_id)
    end
  end
end
