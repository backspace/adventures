defmodule Registrations.Repo.Migrations.ChangeWaydowntownIncarnationdescriptionsToDescriptions do
  @moduledoc false
  use Ecto.Migration

  def change do
    rename(table(:incarnations, prefix: "waydowntown"), :mask, to: :description)
  end
end
