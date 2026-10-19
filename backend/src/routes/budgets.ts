import { Router } from 'express';
import { z } from 'zod';

import { logActivity } from '../db/activity.js';
import { many, one, run, type Db } from '../db/database.js';
import { notFound } from '../lib/http.js';
import { newId } from '../lib/ids.js';
import { budgetJson, type BudgetRow } from '../lib/models.js';
import { currentMember } from '../middleware/auth.js';

/** Expense category id, or "overall" for the whole-family limit. */
const categoryParam = z.string().trim().min(1).max(40);

const putBody = z.object({ limit: z.number().positive().max(1e12) });

/** Mounted under /groups/:groupId/budgets. One budget per category. */
export function budgetRoutes(db: Db) {
  const router = Router({ mergeParams: true });

  router.get('/', (_req, res) => {
    const rows = many<BudgetRow>(
      db,
      `SELECT * FROM budgets WHERE group_id = ? AND deleted_at IS NULL
       ORDER BY category = 'overall' DESC, category`,
      currentMember(res).group_id,
    );
    res.json({ budgets: rows.map(budgetJson) });
  });

  /** Creates or replaces the budget for a category. */
  router.put('/:categoryId', (req, res) => {
    const category = categoryParam.parse(req.params.categoryId);
    const { limit } = putBody.parse(req.body);
    const groupId = currentMember(res).group_id;
    const now = Date.now();
    run(
      db,
      `INSERT INTO budgets (id, group_id, category, amount, updated_at)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT (group_id, category)
       DO UPDATE SET amount = excluded.amount, updated_at = excluded.updated_at,
                     deleted_at = NULL`,
      newId(),
      groupId,
      category,
      limit,
      now,
    );
    const b = one<BudgetRow>(
      db,
      'SELECT * FROM budgets WHERE group_id = ? AND category = ?',
      groupId,
      category,
    )!;
    logActivity(db, res, 'budget_set', { categoryId: category, limit });
    res.json({ budget: budgetJson(b) });
  });

  router.delete('/:categoryId', (req, res) => {
    const category = categoryParam.parse(req.params.categoryId);
    const now = Date.now();
    const result = run(
      db,
      `UPDATE budgets SET deleted_at = ?, updated_at = ?
       WHERE group_id = ? AND category = ? AND deleted_at IS NULL`,
      now,
      now,
      currentMember(res).group_id,
      category,
    );
    if (result.changes === 0) throw notFound('Budget');
    res.status(204).end();
  });

  return router;
}
