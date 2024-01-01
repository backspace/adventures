defmodule Registrations.Repo.Migrations.AddCommentsAndSource do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:comments, :text)
      add(:source, :text)
    end
  end
end
