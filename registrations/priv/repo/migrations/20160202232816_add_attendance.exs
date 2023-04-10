defmodule AdventureRegistrations.Repo.Migrations.AddAttendance do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:attending, :boolean)
    end
  end
end
