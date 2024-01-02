INSERT INTO
  public.users (
    id,
    email,
    crypted_password,
    admin,
    inserted_at,
    updated_at
  )
VALUES
  (
    '5fd0e43c-2d7a-40d2-8d4c-1546a4428cc6',
    'admin@example.com',
    '$2b$12$y46oK5kINhXmnmOp4twqfODz4z0WR8wWc6XPPOob2fZ.yd6E1zCIS',
    TRUE,
    NOW(),
    NOW()
  ),
  (
    'dc3bc4ad-ec08-4d41-8f0c-57603b03d50d',
    'nonadmin@example.com',
    '$2b$12$y46oK5kINhXmnmOp4twqfODz4z0WR8wWc6XPPOob2fZ.yd6E1zCIS',
    FALSE,
    NOW(),
    NOW()
  );