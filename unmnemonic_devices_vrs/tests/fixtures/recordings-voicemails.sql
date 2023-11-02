INSERT INTO
  "unmnemonic_devices"."recordings"(
    "id",
    "type",
    "region_id",
    "destination_id",
    "book_id",
    "url",
    "transcription",
    "character_name",
    "prompt_name",
    "approved",
    "created_at"
  )
VALUES
  (
    '975f5bc8-b527-4445-ad42-cddbd01fc216',
    'voicemail',
    NULL,
    NULL,
    NULL,
    'http://example.com/old-approved',
    NULL,
    'knut',
    '975f5bc8-b527-4445-ad42-cddbd01fc216',
    true,
    '1999-11-01 20:49:17.188764'
  ),
  (
    'af9a306a-6913-4d83-90c4-f595ae020503',
    'voicemail',
    NULL,
    NULL,
    NULL,
    'http://example.com/voicemail-future',
    NULL,
    'knut',
    'af9a306a-6913-4d83-90c4-f595ae020503',
    false,
    '2024-11-01 20:49:17.188764'
  ),
  (
    '4a578222-9a0e-48f0-a023-2be7d873849f',
    'voicemail',
    NULL,
    NULL,
    NULL,
    'http://example.com/voicemail-old',
    NULL,
    'knut',
    '4a578222-9a0e-48f0-a023-2be7d873849f',
    false,
    '2003-11-01 20:49:17.188764'
  ),
  (
    '5d277cab-f567-4f80-9aea-02e0fe387c56',
    'voicemail',
    NULL,
    NULL,
    NULL,
    'http://example.com/voicemail-1',
    NULL,
    'knut',
    '5d277cab-f567-4f80-9aea-02e0fe387c56',
    false,
    '2023-11-01 20:49:17.188764'
  ),
  (
    'da66d949-72cf-4047-8365-8f5999b435bb',
    'voicemail',
    NULL,
    NULL,
    NULL,
    'http://example.com/voicemail-2',
    NULL,
    'knut',
    'da66d949-72cf-4047-8365-8f5999b435bb',
    true,
    '2023-11-01 20:49:17.188764'
  );