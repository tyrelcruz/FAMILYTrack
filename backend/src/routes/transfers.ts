import { Router } from 'express';
import { z } from 'zod';

import { isRecent, logActivity } from '../db/activity.js';
import { many, one, run, type Db } from '../db/database.js';
import { HttpError, notFound } from '../lib/http.js';
import { newId } from '../lib/ids.js';
import { PAYMENT_METHODS, transferJson, type TransferRow } from '../lib/models.js';
import { currentMember, currentUserId } from '../middleware/auth.js';

const method = z.enum(PAYMENT_METHODS).nullable();

const fields = {
  kind: z.enum(['wallet', 'people']),
  amount: z.number().positive().max(1e12),
  fromMethod: method,
  toMethod: method,
  fromMemberId: z.uuid().nullable(),
  toMemberId: z.uuid().nullable(),
  planId: z.uuid().nullable(),
  note: z.string().max(500),
  date: z.number().int(),
};

const createBody = z.object({
  id: z.uuid().optional(),
  ...fields,
  fromMethod: fields.fromMethod.default(null),
  toMethod: fields.toMethod.default(null),
  fromMemberId: fields.fromMemberId.default(null),
  toMemberId: fields.toMemberId.default(null),
  planId: fields.planId.default(null),
  note: fields.note.default(''),
});

const updateBody = z.object(fields).partial();

/** Mounted under /groups/:groupId/transfers. */
export function transferRoutes(db: Db) {
  const router = Router({ mergeParams: true });

  /** A wallet transfer needs two different wallets; a people one two people. */
  const assertValid = (t: TransferRow) => {
    if (t.kind === 'wallet') {
      if (!t.from_method || !t.to_method || t.from_method === t.to_method) {
        throw new HttpError(400, 'A wallet transfer needs two different wallets');
      }
    } else if (!t.from_member_id || !t.to_member_id || t.from_member_id === t.to_member_id) {
      throw new HttpError(400, 'A transfer between people needs two different people');
    }
    for (const id of [t.from_member_id, t.to_member_id]) {
      if (
        id &&
        !one(db, 'SELECT 1 FROM members WHERE id = ? AND group_id = ?', id, t.group_id)
      ) {
        throw new HttpError(400, 'Member is not in this group');
      }
    }
    if (
      t.plan_id &&
      !one(
        db,
        'SELECT 1 FROM plans WHERE id = ? AND group_id = ? AND deleted_at IS NULL',
        t.plan_id,
        t.group_id,
      )
    ) {
      throw new HttpError(400, 'planId is not in this group');
    }
  };

  const find = (groupId: string, id: string) => {
    const t = one<TransferRow>(
      db,
      'SELECT * FROM transfers WHERE id = ? AND group_id = ? AND deleted_at IS NULL',
      id,
      groupId,
    );
    if (!t) throw notFound('Transfer');
    return t;
  };

  const save = (t: TransferRow, insert: boolean) => {
    const cols = [
      t.kind,
      t.amount,
      t.from_method,
      t.to_method,
      t.from_member_id,
      t.to_member_id,
      t.plan_id,
      t.note,
      t.date,
      t.updated_at,
    ] as const;
    if (insert) {
      run(
        db,
        `INSERT INTO transfers
           (kind, amount, from_method, to_method, from_member_id, to_member_id,
            plan_id, note, date, updated_at, id, group_id, created_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        ...cols,
        t.id,
        t.group_id,
        t.created_by,
        t.created_at,
      );
    } else {
      run(
        db,
        `UPDATE transfers SET kind = ?, amount = ?, from_method = ?, to_method = ?,
           from_member_id = ?, to_member_id = ?, plan_id = ?, note = ?, date = ?,
           updated_at = ?
         WHERE id = ?`,
        ...cols,
        t.id,
      );
    }
  };

  router.get('/', (_req, res) => {
    const rows = many<TransferRow>(
      db,
      `SELECT * FROM transfers WHERE group_id = ? AND deleted_at IS NULL
       ORDER BY date DESC`,
      currentMember(res).group_id,
    );
    res.json({ transfers: rows.map(transferJson) });
  });

  router.post('/', (req, res) => {
    const body = createBody.parse(req.body);
    if (body.id && one(db, 'SELECT 1 FROM transfers WHERE id = ?', body.id)) {
      throw new HttpError(409, 'A transfer with that id already exists');
    }
    const now = Date.now();
    const t: TransferRow = {
      id: body.id ?? newId(),
      group_id: currentMember(res).group_id,
      kind: body.kind,
      amount: body.amount,
      from_method: body.fromMethod,
      to_method: body.toMethod,
      from_member_id: body.fromMemberId,
      to_member_id: body.toMemberId,
      plan_id: body.planId,
      note: body.note,
      date: body.date,
      created_by: currentUserId(res),
      created_at: now,
      updated_at: now,
      deleted_at: null,
    };
    assertValid(t);
    save(t, true);
    if (isRecent(t.date)) {
      logActivity(db, res, 'transfer_added', {
        transferId: t.id,
        kind: t.kind,
        amount: t.amount,
        fromMethod: t.from_method,
        toMethod: t.to_method,
        fromMemberId: t.from_member_id,
        toMemberId: t.to_member_id,
      });
    }
    res.status(201).json({ transfer: transferJson(t) });
  });

  router.patch('/:transferId', (req, res) => {
    const body = updateBody.parse(req.body);
    const t = find(currentMember(res).group_id, String(req.params.transferId));
    const updated: TransferRow = {
      ...t,
      kind: body.kind ?? t.kind,
      amount: body.amount ?? t.amount,
      from_method: body.fromMethod === undefined ? t.from_method : body.fromMethod,
      to_method: body.toMethod === undefined ? t.to_method : body.toMethod,
      from_member_id:
        body.fromMemberId === undefined ? t.from_member_id : body.fromMemberId,
      to_member_id: body.toMemberId === undefined ? t.to_member_id : body.toMemberId,
      plan_id: body.planId === undefined ? t.plan_id : body.planId,
      note: body.note ?? t.note,
      date: body.date ?? t.date,
      updated_at: Date.now(),
    };
    assertValid(updated);
    save(updated, false);
    res.json({ transfer: transferJson(updated) });
  });

  router.delete('/:transferId', (req, res) => {
    const t = find(currentMember(res).group_id, String(req.params.transferId));
    const now = Date.now();
    run(
      db,
      'UPDATE transfers SET deleted_at = ?, updated_at = ? WHERE id = ?',
      now,
      now,
      t.id,
    );
    res.status(204).end();
  });

  return router;
}
