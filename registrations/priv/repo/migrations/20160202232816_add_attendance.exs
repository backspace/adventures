defmodule Registrations.Repo.Migrations.AddAttendance do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:attending, :boolean)
    end
  end
end
