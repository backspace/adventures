defmodule Registrations.Repo.Migrations.AddAnswerTypeToPuzzlets do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:puzzlets, prefix: "poles") do
      add(:answer_type, :string, default: "loose_text", null: false)
    end

    create(
      constraint(:puzzlets, :answer_type_valid,
        prefix: "poles",
        check: "answer_type IN ('loose_text', 'strict_text', 'barcode', 'nfc')"
      )
    )
  end
end
