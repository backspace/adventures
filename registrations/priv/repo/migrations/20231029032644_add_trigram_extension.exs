defmodule Registrations.Repo.Migrations.AddTrigramExtension do
  @moduledoc false
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm", "DROP EXTENSION IF EXISTS pg_trgm")
  end
end
