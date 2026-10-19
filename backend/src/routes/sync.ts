import { Router } from 'express';
import { z } from 'zod';

import { many, one, type Db } from '../db/database.js';
import {
  activityJson,
  budgetJson,
  groupJson,
  memberJson,
  planJson,
  transactionJson,
  transferJson,
  type ActivityRow,
  type BudgetRow,
  type GroupRow,
  type MemberRow,
  type PlanRow,
  type TransactionRow,
  type TransferRow,
} from '../lib/models.js';
import { currentMember } from '../middleware/auth.js';

const syncQuery = z.object({
  /** `serverTime` from the previous sync; omit or 0 for a full download. */
  since: z.coerce.number().int().min(0).default(0),
});

/**
 * Mounted under /groups/:groupId/sync.
 *
 * Returns every member, plan, transaction and budget changed at or after `since`,
 * deletes included (`deleted: true`), so each device can mirror the group.
 * Rows changed in the same millisecond may come back twice; applying them
 * is idempotent.
 */
export function syncRoutes(db: Db) {
  const router = Router({ mergeParams: true });

  router.get('/', (req, res) => {
    const { since } = syncQuery.parse(req.query);
    const groupId = currentMember(res).group_id;
    // Taken before reading so nothing written during the read is skipped.
    const serverTime = Date.now();
    const changed = <T>(table: string) =>
      many<T>(
        db,
        `SELECT * FROM ${table} WHERE group_id = ? AND updated_at >= ?
         ORDER BY updated_at`,
        groupId,
        since,
      );
    const group = one<GroupRow>(db, 'SELECT * FROM groups WHERE id = ?', groupId)!;
    res.json({
      serverTime,
      group: groupJson(group),
      members: changed<MemberRow>('members').map(memberJson),
      plans: changed<PlanRow>('plans').map(planJson),
      transactions: changed<TransactionRow>('transactions').map(transactionJson),
      budgets: changed<BudgetRow>('budgets').map(budgetJson),
      transfers: changed<TransferRow>('transfers').map(transferJson),
      // Newest 200 events since the last sync, for notifications.
      activity: many<ActivityRow>(
        db,
        `SELECT * FROM activity WHERE group_id = ? AND created_at >= ?
         ORDER BY created_at DESC LIMIT 200`,
        groupId,
        since,
      ).map(activityJson),
    });
  });

  return router;
}
