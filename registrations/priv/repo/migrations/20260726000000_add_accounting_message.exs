defmodule Registrations.Repo.Migrations.AddAccountingMessage do
  use Ecto.Migration

  @prefix "landgrab"

  def change do
    alter table(:events, prefix: @prefix) do
      # Takver's scheduled "accounting" message: sent once to every team when
      # accounting_at passes (after the subversion invite, before the endgame).
      # Body is supervisor-editable; the sent stamp makes it one-shot.
      add(:accounting_at, :utc_datetime)
      add(:accounting_body, :text)
      add(:accounting_sent_at, :utc_datetime)
    end
  end
end
