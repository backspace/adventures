defmodule Registrations.Repo.Migrations.AddWaydowntownSchema do
  @moduledoc false
  use Ecto.Migration

  def up do
    execute("CREATE SCHEMA waydowntown")
  end

  def down do
    execute("DROP SCHEMA waydowntown")
  end
end
