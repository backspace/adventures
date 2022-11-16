defmodule AdventureRegistrations.Repo.Migrations.AddRenderedContent do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add(:rendered_content, :text)
    end
  end
end
