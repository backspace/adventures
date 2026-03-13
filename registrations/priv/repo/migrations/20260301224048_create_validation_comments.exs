defmodule Registrations.Repo.Migrations.CreateValidationComments do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:validation_comments, prefix: "waydowntown", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:specification_validation_id, references(:specification_validations, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:answer_id, references(:answers, type: :uuid, on_delete: :delete_all))

      add(:field, :string)
      add(:comment, :text)
      add(:suggested_value, :text)

      timestamps()
    end
  end
end
