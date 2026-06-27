defmodule Registrations.Repo.Migrations.RenamePolesSchemaToLandgrab do
  @moduledoc false
  use Ecto.Migration

  def up do
    execute("ALTER SCHEMA poles RENAME TO landgrab")
  end

  def down do
    execute("ALTER SCHEMA landgrab RENAME TO poles")
  end
end
