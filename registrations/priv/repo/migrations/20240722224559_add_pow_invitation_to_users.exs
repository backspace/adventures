defmodule Registrations.Repo.Migrations.AddPowInvitationToUsers do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:invitation_token, :string)
      add(:invitation_accepted_at, :utc_datetime)
      add(:invited_by_id, references("users", on_delete: :nothing, type: :binary_id))
    end

    create(unique_index(:users, [:invitation_token]))
  end
end
