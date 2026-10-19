import { Router } from 'express';
import { z } from 'zod';

import { isRecent, logActivity } from '../db/activity.js';
import { many, one, run, type Db } from '../db/database.js';
import { HttpError, notFound } from '../lib/http.js';
import { newId } from '../lib/ids.js';
import {
  PAYMENT_METHODS,
  transactionJson,
  type TransactionRow,
} from '../lib/models.js';
import { currentMember, currentUserId } from '../middleware/auth.js';

const fields = {
  title: z.string().trim().min(1).max(120),
  amount: z.number().positive().max(1e12),
  type: z.enum(['income', 'expense']),
  categoryId: z.string().trim().min(1).max(40),
  /** Milliseconds since epoch, like the app stores it. */
  date: z.number().int(),
  note: z.string().max(500),
  /** Null means the group owner. */
  memberId: z.uuid().nullable(),
  /** Trip or monthly plan this expense belongs to. */
  planId: z.uuid().nullable(),
  paymentMethod: z.enum(PAYMENT_METHODS).nullable(),
};

const createBody = z.object({
  id: z.uuid().optional(),
  ...fields,
  note: fields.note.default(''),
  memberId: fields.memberId.default(null),
  planId: fields.planId.default(null),
  paymentMethod: fields.paymentMethod.default(null),
});

const updateBody = z.object(fields).partial();

const listQuery = z.object({
  /** e.g. 2026-10; omit for everything. */
  month: z
    .string()
    .regex(/^\d{4}-\d{2}$/)
    .optional(),
});

/** Mounted under /groups/:groupId/transactions. */
export function transactionRoutes(db: Db) {
  const router = Router({ mergeParams: true });

  const assertMemberInGroup = (groupId: string, memberId: string | null | undefined) => {
    if (!memberId) return;
    const ok = one(
      db,
      'SELECT 1 FROM members WHERE id = ? AND group_id = ? AND deleted_at IS NULL',
      memberId,
      groupId,
    );
    if (!ok) throw new HttpError(400, 'memberId is not in this group');
  };

  const assertPlanInGroup = (groupId: string, planId: string | null | undefined) => {
    if (!planId) return;
    const ok = one(
      db,
      'SELECT 1 FROM plans WHERE id = ? AND group_id = ? AND deleted_at IS NULL',
      planId,
      groupId,
    );
    if (!ok) throw new HttpError(400, 'planId is not in this group');
  };

  const find = (groupId: string, id: string) => {
    const t = one<TransactionRow>(
      db,
      'SELECT * FROM transactions WHERE id = ? AND group_id = ? AND deleted_at IS NULL',
      id,
      groupId,
    );
    if (!t) throw notFound('Transaction');
    return t;
  };

  router.get('/', (req, res) => {
    const { month } = listQuery.parse(req.query);
    const groupId = currentMember(res).group_id;
    let from = Number.MIN_SAFE_INTEGER;
    let to = Number.MAX_SAFE_INTEGER;
    if (month) {
      const [y, m] = month.split('-').map(Number) as [number, number];
      // Month bounds in UTC; the app sends local times, so clients that need
      // exact local-month edges should filter after a sync instead.
      from = Date.UTC(y, m - 1, 1);
      to = Date.UTC(y, m, 1);
    }
    const rows = many<TransactionRow>(
      db,
      `SELECT * FROM transactions
       WHERE group_id = ? AND deleted_at IS NULL AND date >= ? AND date < ?
       ORDER BY date DESC, created_at DESC`,
      groupId,
      from,
      to,
    );
    res.json({ transactions: rows.map(transactionJson) });
  });

  router.post('/', (req, res) => {
    const body = createBody.parse(req.body);
    const groupId = currentMember(res).group_id;
    assertMemberInGroup(groupId, body.memberId);
    assertPlanInGroup(groupId, body.planId);
    if (body.id && one(db, 'SELECT 1 FROM transactions WHERE id = ?', body.id)) {
      throw new HttpError(409, 'A transaction with that id already exists');
    }
    const now = Date.now();
    const t: TransactionRow = {
      id: body.id ?? newId(),
      group_id: groupId,
      member_id: body.memberId,
      title: body.title,
      amount: body.amount,
      type: body.type,
      category: body.categoryId,
      date: body.date,
      note: body.note,
      plan_id: body.planId,
      payment_method: body.paymentMethod,
      created_by: currentUserId(res),
      created_at: now,
      updated_at: now,
      deleted_at: null,
    };
    run(
      db,
      `INSERT INTO transactions
         (id, group_id, member_id, title, amount, type, category, date, note,
          plan_id, payment_method, created_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      t.id,
      t.group_id,
      t.member_id,
      t.title,
      t.amount,
      t.type,
      t.category,
      t.date,
      t.note,
      t.plan_id,
      t.payment_method,
      t.created_by,
      t.created_at,
      t.updated_at,
    );
    if (isRecent(t.date)) {
      logActivity(db, res, 'transaction_added', {
        transactionId: t.id,
        title: t.title,
        amount: t.amount,
        type: t.type,
        categoryId: t.category,
        memberId: t.member_id,
        planId: t.plan_id,
      });
    }
    res.status(201).json({ transaction: transactionJson(t) });
  });

  router.patch('/:transactionId', (req, res) => {
    const body = updateBody.parse(req.body);
    const groupId = currentMember(res).group_id;
    const t = find(groupId, String(req.params.transactionId));
    assertMemberInGroup(groupId, body.memberId);
    assertPlanInGroup(groupId, body.planId);
    const updated: TransactionRow = {
      ...t,
      title: body.title ?? t.title,
      amount: body.amount ?? t.amount,
      type: body.type ?? t.type,
      category: body.categoryId ?? t.category,
      date: body.date ?? t.date,
      note: body.note ?? t.note,
      member_id: body.memberId === undefined ? t.member_id : body.memberId,
      plan_id: body.planId === undefined ? t.plan_id : body.planId,
      payment_method:
        body.paymentMethod === undefined ? t.payment_method : body.paymentMethod,
      updated_at: Date.now(),
    };
    run(
      db,
      `UPDATE transactions
       SET title = ?, amount = ?, type = ?, category = ?, date = ?, note = ?,
           member_id = ?, plan_id = ?, payment_method = ?, updated_at = ?
       WHERE id = ?`,
      updated.title,
      updated.amount,
      updated.type,
      updated.category,
      updated.date,
      updated.note,
      updated.member_id,
      updated.plan_id,
      updated.payment_method,
      updated.updated_at,
      t.id,
    );
    res.json({ transaction: transactionJson(updated) });
  });

  router.delete('/:transactionId', (req, res) => {
    const t = find(currentMember(res).group_id, String(req.params.transactionId));
    const now = Date.now();
    run(
      db,
      'UPDATE transactions SET deleted_at = ?, updated_at = ? WHERE id = ?',
      now,
      now,
      t.id,
    );
    res.status(204).end();
  });

  return router;
}
