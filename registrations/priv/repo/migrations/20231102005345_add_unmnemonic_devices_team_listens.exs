defmodule Registrations.Repo.Migrations.AddUnmnemonicDevicesTeamListens do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table("teams") do
      add(:listens, :integer, default: 0)
    end
  end
end
