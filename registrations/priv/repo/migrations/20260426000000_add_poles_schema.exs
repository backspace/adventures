defmodule Registrations.Repo.Migrations.AddPolesSchema do
  @moduledoc false
  use Ecto.Migration

  def up do
    execute("CREATE SCHEMA poles")
  end

  def down do
    execute("DROP SCHEMA poles")
  end
end
