defmodule Registrations.Repo.Migrations.AddStatusToValidationComments do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:validation_comments, prefix: "waydowntown") do
      add(:status, :string, null: false, default: "pending")
    end
  end
end
