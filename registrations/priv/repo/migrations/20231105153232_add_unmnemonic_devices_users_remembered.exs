defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesUsersRemembered do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:remembered, :integer, default: 0)
    end
  end
end
