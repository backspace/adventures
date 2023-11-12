UPDATE
  "unmnemonic_devices"."recordings"
SET
  team_listen_ids = ARRAY_APPEND(
    team_listen_ids,
    '5b0ccfd0-6aad-42f6-85ad-ee19a21f836e'
  )
WHERE
  id = '975f5bc8-b527-4445-ad42-cddbd01fc216';