defmodule Registrations.Accounts do
  @moduledoc false
  import Ecto.Query, warn: false

  alias Registrations.Repo
  alias Registrations.UserRole

  def list_user_roles(user) do
    from(r in UserRole, where: r.user_id == ^user.id)
    |> Repo.all()
    |> Repo.preload([:user, :assigned_by])
  end

  def list_all_user_roles(filters \\ %{}) do
    UserRole
    |> filter_roles_query(filters)
    |> Repo.all()
    |> Repo.preload([:user, :assigned_by])
  end

  defp filter_roles_query(query, filters) do
    Enum.reduce(filters, query, fn
      {"role", role}, query when is_binary(role) ->
        from(r in query, where: r.role == ^role)

      _, query ->
        query
    end)
  end

  def get_user_role!(id) do
    UserRole
    |> Repo.get!(id)
    |> Repo.preload([:user, :assigned_by])
  end

  def assign_role(user_id, role, assigned_by_id \\ nil) do
    %UserRole{}
    |> UserRole.changeset(%{user_id: user_id, role: role, assigned_by_id: assigned_by_id})
    |> Repo.insert()
    |> case do
      {:ok, user_role} -> {:ok, Repo.preload(user_role, [:user, :assigned_by])}
      error -> error
    end
  end

  def remove_role(id) do
    UserRole
    |> Repo.get!(id)
    |> Repo.delete()
  end

  def has_role?(user, role) do
    Repo.exists?(from(r in UserRole, where: r.user_id == ^user.id and r.role == ^role))
  end

  def list_users_with_role(role) do
    from(r in UserRole,
      where: r.role == ^role,
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.map(& &1.user)
  end
end
