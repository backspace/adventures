defmodule Cr2016site.Repo.Migrations.AddAccessibility do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:accessibility, :text)
    end
  end
end
