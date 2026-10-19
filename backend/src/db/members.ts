import { z } from 'zod';

import { run, transaction, type Db } from './database.js';
import type { MemberRow } from '../lib/models.js';

/** ARGB color int, as Flutter's `Color.toARGB32()` produces. */
export const colorSchema = z.number().int().min(0).max(0xffffffff);

export function insertMember(db: Db, m: MemberRow) {
  run(
    db,
    `INSERT INTO members
       (id, group_id, user_id, name, color, role, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    m.id,
    m.group_id,
    m.user_id,
    m.name,
    m.color,
    m.role,
    m.created_at,
    m.updated_at,
  );
}

/**
 * Soft-deletes [m]; their transactions stay in the group and fall back to
 * the owner (member_id null), matching the app.
 */
export function removeMember(db: Db, m: MemberRow) {
  const now = Date.now();
  transaction(db, () => {
    run(
      db,
      'UPDATE transactions SET member_id = NULL, updated_at = ? WHERE member_id = ?',
      now,
      m.id,
    );
    run(
      db,
      'UPDATE members SET deleted_at = ?, updated_at = ? WHERE id = ?',
      now,
      now,
      m.id,
    );
  });
}
