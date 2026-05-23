defmodule Registrations.Repo.Migrations.AddPolesAttachmentsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:attachments, prefix: "poles", primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))

      add(
        :pole_id,
        references(:poles, type: :uuid, prefix: "poles", on_delete: :delete_all)
      )

      add(
        :puzzlet_id,
        references(:puzzlets, type: :uuid, prefix: "poles", on_delete: :delete_all)
      )

      add(:data, :binary, null: false)
      add(:content_type, :string, null: false)
      add(:byte_size, :integer, null: false)

      add(
        :creator_id,
        references(:users, type: :uuid, prefix: "public", on_delete: :nilify_all)
      )

      timestamps()
    end

    create(
      constraint(:attachments, :exactly_one_parent,
        prefix: "poles",
        check: "(pole_id IS NOT NULL)::int + (puzzlet_id IS NOT NULL)::int = 1"
      )
    )

    create(index(:attachments, [:pole_id], prefix: "poles"))
    create(index(:attachments, [:puzzlet_id], prefix: "poles"))
  end
end
