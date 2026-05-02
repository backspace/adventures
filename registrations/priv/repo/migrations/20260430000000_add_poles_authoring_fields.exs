defmodule Registrations.Repo.Migrations.AddPolesAuthoringFields do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:poles, prefix: "poles") do
      add(:status, :string, null: false, default: "draft")
      add(:notes, :text)
      add(:accuracy_m, :float)

      add(
        :creator_id,
        references(:users, type: :uuid, prefix: "public", on_delete: :nilify_all)
      )
    end

    alter table(:puzzlets, prefix: "poles") do
      add(
        :creator_id,
        references(:users, type: :uuid, prefix: "public", on_delete: :nilify_all)
      )
    end

    create(index(:poles, [:status], prefix: "poles"))
    create(index(:poles, [:creator_id], prefix: "poles"))
    create(index(:puzzlets, [:creator_id], prefix: "poles"))

    # Anything that was seeded before this migration was implicitly trusted —
    # mark it validated so the live game keeps showing existing poles.
    execute(
      ~s|UPDATE "poles"."poles" SET status = 'validated'|,
      ~s|UPDATE "poles"."poles" SET status = 'draft'|
    )
  end
end
