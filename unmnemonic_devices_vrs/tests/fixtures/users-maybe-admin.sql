INSERT INTO
  public.users (
    id,
    email,
    password_hash,
    admin,
    inserted_at,
    updated_at
  )
VALUES
  (
    '5fd0e43c-2d7a-40d2-8d4c-1546a4428cc6',
    'admin@example.com',
    '$pbkdf2-sha512$100000$YQDYVdAxOPRz3ybRnnbYWw==$+qQJYU5PzVyUVgCiMNiC8KDrya1XhlgPfBVjOnEfXSUP9tq8FzkITJWgp4Q/FjjIrXrFatiB1l2TITqw0IQU6A==',
    TRUE,
    NOW(),
    NOW()
  ),
  (
    'dc3bc4ad-ec08-4d41-8f0c-57603b03d50d',
    'nonadmin@example.com',
    '$pbkdf2-sha512$100000$N9405dEGWU7FdGWEbe/dZA==$ffKo0+JccsA+0wk6RjPrznGqAricoycWpcbmzewLunBYhpbZnSkVgrs4uhcaDDZ03CVyT1G4ptNXX7dAhzCW8w==',
    FALSE,
    NOW(),
    NOW()
  );
