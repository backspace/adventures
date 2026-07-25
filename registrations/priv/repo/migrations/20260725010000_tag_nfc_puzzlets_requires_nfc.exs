defmodule Registrations.Repo.Migrations.TagNfcPuzzletsRequiresNfc do
  use Ecto.Migration

  # Flag every NFC-answer puzzlet with the `requires_nfc` accessibility tag, so
  # a participant whose device can't scan NFC (declared as a need) is routed to
  # a non-NFC puzzlet at the stake — or, where a stake is NFC-only, offered the
  # claim-without-solving path. Idempotent: skips puzzlets already tagged.
  def up do
    execute("""
    UPDATE landgrab.puzzlets
    SET accessibility_tags = array_append(coalesce(accessibility_tags, '{}'), 'requires_nfc')
    WHERE answer_type = 'nfc'
      AND NOT ('requires_nfc' = ANY(coalesce(accessibility_tags, '{}')))
    """)
  end

  def down do
    execute("""
    UPDATE landgrab.puzzlets
    SET accessibility_tags = array_remove(accessibility_tags, 'requires_nfc')
    WHERE answer_type = 'nfc'
    """)
  end
end
