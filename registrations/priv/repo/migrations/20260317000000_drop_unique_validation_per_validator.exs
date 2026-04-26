defmodule Registrations.Repo.Migrations.DropUniqueValidationPerValidator do
  @moduledoc false
  use Ecto.Migration

  def change do
    drop(unique_index(:specification_validations, [:specification_id, :validator_id], prefix: "waydowntown"))
  end
end
