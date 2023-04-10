defmodule AdventureRegistrationsWeb.Registration do
  import Ecto.Changeset, only: [put_change: 3]

  def create(changeset, repo) do
    changeset
    |> put_change(:crypted_password, hashed_password(changeset.params["password"]))
    |> repo.insert()
  end

  def update(changeset, repo) do
    changeset
    |> put_change(:crypted_password, hashed_password(changeset.params["new_password"]))
    |> repo.update()
  end

  def delete(changeset, repo) do
    changeset
    |> repo.delete
  end

  # FIXME this was private but now shared with Reset!
  def hashed_password(password) do
    Bcrypt.hash_pwd_salt(password)
  end
end
