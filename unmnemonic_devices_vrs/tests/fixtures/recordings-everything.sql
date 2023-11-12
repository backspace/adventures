INSERT INTO
  "unmnemonic_devices"."regions" ("id", "name")
VALUES
  ('a1e3d7df-a9ff-4382-9a6a-c379d119ee18', 'region');

INSERT INTO
  "unmnemonic_devices"."destinations" ("id", "region_id", "description")
VALUES
  (
    '7ef1bbc5-f5ca-4ad3-b89b-3afad164fa73',
    'a1e3d7df-a9ff-4382-9a6a-c379d119ee18',
    'a destination'
  );

INSERT INTO
  "unmnemonic_devices"."books" ("id", "title")
VALUES
  ('bb577b9a-1d9b-4652-bfe9-44b28c27c7c8', 'a book');

INSERT INTO
  "public"."teams" ("id", "inserted_at", "updated_at")
VALUES
  (
    '5ebe8109-c543-45b9-82c1-d7ab2cf76d21',
    now(),
    now()
  );

INSERT INTO
  "unmnemonic_devices"."recordings"(
    "id",
    "region_id",
    "destination_id",
    "book_id",
    "team_id",
    "url"
  )
VALUES
  (
    '1899fd7b-aa56-4877-8c77-2373e8704a11',
    'a1e3d7df-a9ff-4382-9a6a-c379d119ee18',
    NULL,
    NULL,
    NULL,
    'http://example.com/region-recording'
  ),
  (
    '347d725d-070e-4c16-bf9e-450beb79b9e1',
    NULL,
    '7ef1bbc5-f5ca-4ad3-b89b-3afad164fa73',
    NULL,
    NULL,
    'http://example.com/destination-recording'
  ),
  (
    '0ab8b849-79ce-4a39-9101-420a406655e6',
    NULL,
    NULL,
    'bb577b9a-1d9b-4652-bfe9-44b28c27c7c8',
    NULL,
    'http://example.com/book-recording'
  ),
  (
    '1724f6f3-eda3-46e8-b08f-5669411f9466',
    NULL,
    NULL,
    NULL,
    '5ebe8109-c543-45b9-82c1-d7ab2cf76d21',
    'http://example.com/team-recording'
  );