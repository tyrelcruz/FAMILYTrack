import type { Response } from 'express';

import { newId } from '../lib/ids.js';
import { currentMember, currentUserId } from '../middleware/auth.js';
import { run, type Db } from './database.js';

export type ActivityKind =
  | 'transaction_added'
  | 'member_joined'
  | 'member_added'
  | 'plan_created'
  | 'budget_set'
  | 'transfer_added';

/** Records something the signed-in member did, for the family's feed. */
export function logActivity(
  db: Db,
  res: Response,
  kind: ActivityKind,
  data: Record<string, unknown>,
) {
  const me = currentMember(res);
  run(
    db,
    `INSERT INTO activity (id, group_id, actor_user_id, actor_name, kind, data, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    newId(),
    me.group_id,
    currentUserId(res),
    me.name,
    kind,
    JSON.stringify(data),
    Date.now(),
  );
}

/**
 * Only fresh entries make news; older ones uploaded in bulk (e.g. when a
 * phone joins with existing data) would just flood the feed.
 */
export const isRecent = (date: number) =>
  Math.abs(Date.now() - date) < 3 * 24 * 60 * 60 * 1000;
