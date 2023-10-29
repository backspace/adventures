defmodule AdventureRegistrations.Repo.Migrations.AddTrigramExtension do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION pg_trgm", "DROP EXTENSION pg_trgm")
  end
end
