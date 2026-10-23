/**
 * Append-only list of schema changes; index + 1 is the schema version.
 *
 * Synced tables carry `updated_at` (ms) and a soft-delete `deleted_at` so
 * clients can pull everything that changed since their last sync, deletes
 * included.
 */
export const migrations: string[] = [
  `
  CREATE TABLE users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    created_at INTEGER NOT NULL
  );

  CREATE TABLE groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    invite_code TEXT NOT NULL UNIQUE,
    owner_id TEXT NOT NULL REFERENCES users(id),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  );

  -- A person in a family group. user_id is null for members without an
  -- account (e.g. kids) that someone else tracks spending for.
  CREATE TABLE members (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id TEXT REFERENCES users(id),
    name TEXT NOT NULL,
    color INTEGER NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('owner', 'member')),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER
  );
  CREATE UNIQUE INDEX members_one_per_user
    ON members(group_id, user_id)
    WHERE user_id IS NOT NULL AND deleted_at IS NULL;
  CREATE INDEX members_sync ON members(group_id, updated_at);

  CREATE TABLE transactions (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    member_id TEXT REFERENCES members(id),
    title TEXT NOT NULL,
    amount REAL NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    category TEXT NOT NULL,
    date INTEGER NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    created_by TEXT NOT NULL REFERENCES users(id),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER
  );
  CREATE INDEX transactions_sync ON transactions(group_id, updated_at);
  CREATE INDEX transactions_date ON transactions(group_id, date);

  CREATE TABLE budgets (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    category TEXT NOT NULL,
    amount REAL NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (group_id, category)
  );
  CREATE INDEX budgets_sync ON budgets(group_id, updated_at);
  `,
  `
  -- A budget for a trip or a month: how much there is, where it's kept
  -- (cash, e-wallet, card, bank) and how it's divided between members.
  CREATE TABLE plans (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('trip', 'monthly')),
    start_date INTEGER NOT NULL,
    end_date INTEGER NOT NULL,
    funds TEXT NOT NULL DEFAULT '{}',
    shares TEXT NOT NULL DEFAULT '{}',
    split TEXT NOT NULL CHECK (split IN ('equal', 'custom')),
    created_by TEXT NOT NULL REFERENCES users(id),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER
  );
  CREATE INDEX plans_sync ON plans(group_id, updated_at);

  ALTER TABLE transactions ADD COLUMN plan_id TEXT;
  ALTER TABLE transactions ADD COLUMN payment_method TEXT;
  `,
  `
  -- Money moved without being spent: between wallets (cash -> e-wallet)
  -- or between people (Ana gives Sam 500). Not income or expense.
  CREATE TABLE transfers (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('wallet', 'people')),
    amount REAL NOT NULL,
    from_method TEXT,
    to_method TEXT,
    from_member_id TEXT,
    to_member_id TEXT,
    plan_id TEXT,
    note TEXT NOT NULL DEFAULT '',
    date INTEGER NOT NULL,
    created_by TEXT NOT NULL REFERENCES users(id),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER
  );
  CREATE INDEX transfers_sync ON transfers(group_id, updated_at);

  -- What happened in the family, for notifications. Append-only.
  CREATE TABLE activity (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    actor_user_id TEXT REFERENCES users(id),
    actor_name TEXT NOT NULL,
    kind TEXT NOT NULL,
    data TEXT NOT NULL DEFAULT '{}',
    created_at INTEGER NOT NULL
  );
  CREATE INDEX activity_feed ON activity(group_id, created_at);
  `,
  `
  -- More kinds of plan, plus where it is and what it's about. SQLite can't
  -- change a CHECK, so the table is rebuilt.
  CREATE TABLE plans_new (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('trip', 'event', 'monthly', 'custom')),
    start_date INTEGER NOT NULL,
    end_date INTEGER NOT NULL,
    funds TEXT NOT NULL DEFAULT '{}',
    shares TEXT NOT NULL DEFAULT '{}',
    split TEXT NOT NULL CHECK (split IN ('equal', 'custom')),
    destination TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    created_by TEXT NOT NULL REFERENCES users(id),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER
  );
  INSERT INTO plans_new
    (id, group_id, name, kind, start_date, end_date, funds, shares, split,
     created_by, created_at, updated_at, deleted_at)
  SELECT id, group_id, name, kind, start_date, end_date, funds, shares, split,
         created_by, created_at, updated_at, deleted_at
  FROM plans;
  DROP TABLE plans;
  ALTER TABLE plans_new RENAME TO plans;
  CREATE INDEX plans_sync ON plans(group_id, updated_at);
  `,
  `
  -- A receipt or photo per transaction; the image file lives on disk.
  ALTER TABLE transactions ADD COLUMN has_photo INTEGER NOT NULL DEFAULT 0;
  `,
  `
  -- A cover photo per plan; the image file lives on disk.
  ALTER TABLE plans ADD COLUMN has_cover INTEGER NOT NULL DEFAULT 0;
  `,
];
