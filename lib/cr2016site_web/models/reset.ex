defmodule Cr2016siteWeb.Reset do
  import Ecto.Changeset, only: [put_change: 3]
  alias Cr2016siteWeb.User

  def create(user, repo) do
    if user do
      User.reset_changeset(user)
      |> put_change(:recovery_hash, Comeonin.Bcrypt.hashpwsalt("1"))
      |> repo.update()
    else
      {:error, :user_not_found}
    end
  end

  def update(changeset, repo) do
    changeset
    |> put_change(:crypted_password, Cr2016site.Registration.hashed_password(changeset.params["new_password"]))
    |> put_change(:recovery_hash, nil)
    |> repo.update()
  end
end
