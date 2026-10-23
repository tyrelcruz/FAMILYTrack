import express, { Router } from 'express';
import { z } from 'zod';

import { logActivity } from '../db/activity.js';
import { many, one, run, transaction, type Db } from '../db/database.js';
import { looksLikeImage, type BlobStore } from '../lib/blob-store.js';
import { HttpError, notFound } from '../lib/http.js';
import { newId } from '../lib/ids.js';
import { PAYMENT_METHODS, planJson, type PlanRow } from '../lib/models.js';
import { currentMember, currentUserId } from '../middleware/auth.js';

const money = z.number().min(0).max(1e12);

const fields = {
  name: z.string().trim().min(1).max(80),
  kind: z.enum(['trip', 'event', 'monthly', 'custom']),
  /** Milliseconds since epoch; both days are included. */
  startDate: z.number().int(),
  endDate: z.number().int(),
  /** How much is kept in each place, e.g. { cash: 5000, ewallet: 2000 }. */
  funds: z.partialRecord(z.enum(PAYMENT_METHODS), money),
  /** Each member's share of the budget, keyed by member id. */
  shares: z.record(z.uuid(), money),
  split: z.enum(['equal', 'custom']),
  /** e.g. "Tokyo, Japan"; empty when it isn't somewhere. */
  destination: z.string().trim().max(120),
  description: z.string().trim().max(1000),
};

const createBody = z.object({
  id: z.uuid().optional(),
  ...fields,
  destination: fields.destination.default(''),
  description: fields.description.default(''),
});
const updateBody = z.object(fields).partial();

const coverKey = (groupId: string, planId: string) =>
  `${groupId}/covers/${planId}`;

/** Mounted under /groups/:groupId/plans. */
export function planRoutes(db: Db, blobs: BlobStore) {
  const router = Router({ mergeParams: true });

  const find = (groupId: string, id: string) => {
    const p = one<PlanRow>(
      db,
      'SELECT * FROM plans WHERE id = ? AND group_id = ? AND deleted_at IS NULL',
      id,
      groupId,
    );
    if (!p) throw notFound('Plan');
    return p;
  };

  const assertDates = (start: number, end: number) => {
    if (end < start) throw new HttpError(400, 'endDate must be on or after startDate');
  };

  router.get('/', (_req, res) => {
    const rows = many<PlanRow>(
      db,
      `SELECT * FROM plans WHERE group_id = ? AND deleted_at IS NULL
       ORDER BY start_date DESC`,
      currentMember(res).group_id,
    );
    res.json({ plans: rows.map(planJson) });
  });

  router.post('/', (req, res) => {
    const body = createBody.parse(req.body);
    assertDates(body.startDate, body.endDate);
    if (body.id && one(db, 'SELECT 1 FROM plans WHERE id = ?', body.id)) {
      throw new HttpError(409, 'A plan with that id already exists');
    }
    const now = Date.now();
    const p: PlanRow = {
      id: body.id ?? newId(),
      group_id: currentMember(res).group_id,
      name: body.name,
      kind: body.kind,
      start_date: body.startDate,
      end_date: body.endDate,
      funds: JSON.stringify(body.funds),
      shares: JSON.stringify(body.shares),
      split: body.split,
      destination: body.destination,
      description: body.description,
      created_by: currentUserId(res),
      created_at: now,
      updated_at: now,
      has_cover: 0,
      deleted_at: null,
    };
    run(
      db,
      `INSERT INTO plans
         (id, group_id, name, kind, start_date, end_date, funds, shares, split,
          destination, description, created_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      p.id,
      p.group_id,
      p.name,
      p.kind,
      p.start_date,
      p.end_date,
      p.funds,
      p.shares,
      p.split,
      p.destination,
      p.description,
      p.created_by,
      p.created_at,
      p.updated_at,
    );
    logActivity(db, res, 'plan_created', {
      planId: p.id,
      name: p.name,
      kind: p.kind,
      total: Object.values(body.funds).reduce((s, v) => s + (v ?? 0), 0),
    });
    res.status(201).json({ plan: planJson(p) });
  });

  router.patch('/:planId', (req, res) => {
    const body = updateBody.parse(req.body);
    const p = find(currentMember(res).group_id, String(req.params.planId));
    const updated: PlanRow = {
      ...p,
      name: body.name ?? p.name,
      kind: body.kind ?? p.kind,
      start_date: body.startDate ?? p.start_date,
      end_date: body.endDate ?? p.end_date,
      funds: body.funds ? JSON.stringify(body.funds) : p.funds,
      shares: body.shares ? JSON.stringify(body.shares) : p.shares,
      split: body.split ?? p.split,
      destination: body.destination ?? p.destination,
      description: body.description ?? p.description,
      updated_at: Date.now(),
    };
    assertDates(updated.start_date, updated.end_date);
    run(
      db,
      `UPDATE plans SET name = ?, kind = ?, start_date = ?, end_date = ?,
         funds = ?, shares = ?, split = ?, destination = ?, description = ?,
         updated_at = ?
       WHERE id = ?`,
      updated.name,
      updated.kind,
      updated.start_date,
      updated.end_date,
      updated.funds,
      updated.shares,
      updated.split,
      updated.destination,
      updated.description,
      updated.updated_at,
      p.id,
    );
    res.json({ plan: planJson(updated) });
  });

  // ── Cover photos ─────────────────────────────────────────────────────

  /** Stores the request body (an image) as this plan's cover. */
  router.put(
    '/:planId/cover',
    express.raw({ type: ['image/*', 'application/octet-stream'], limit: '6mb' }),
    (req, res) => {
      const p = find(currentMember(res).group_id, String(req.params.planId));
      const bytes = req.body;
      if (!Buffer.isBuffer(bytes) || bytes.length === 0) {
        throw new HttpError(400, 'Send the image as the request body');
      }
      if (!looksLikeImage(bytes)) throw new HttpError(400, 'That isn’t an image');
      blobs.put(coverKey(p.group_id, p.id), bytes);
      run(
        db,
        'UPDATE plans SET has_cover = 1, updated_at = ? WHERE id = ?',
        Date.now(),
        p.id,
      );
      res.status(204).end();
    },
  );

  router.get('/:planId/cover', (req, res) => {
    const p = find(currentMember(res).group_id, String(req.params.planId));
    const file = blobs.path(coverKey(p.group_id, p.id));
    if (!p.has_cover || !file) throw notFound('Cover');
    res.type('image/jpeg').sendFile(file);
  });

  router.delete('/:planId/cover', (req, res) => {
    const p = find(currentMember(res).group_id, String(req.params.planId));
    blobs.remove(coverKey(p.group_id, p.id));
    run(
      db,
      'UPDATE plans SET has_cover = 0, updated_at = ? WHERE id = ?',
      Date.now(),
      p.id,
    );
    res.status(204).end();
  });

  /** Removes the plan; its expenses stay as normal transactions. */
  router.delete('/:planId', (req, res) => {
    const p = find(currentMember(res).group_id, String(req.params.planId));
    const now = Date.now();
    transaction(db, () => {
      run(
        db,
        'UPDATE transactions SET plan_id = NULL, updated_at = ? WHERE plan_id = ?',
        now,
        p.id,
      );
      run(
        db,
        'UPDATE transfers SET plan_id = NULL, updated_at = ? WHERE plan_id = ?',
        now,
        p.id,
      );
      run(
        db,
        'UPDATE plans SET deleted_at = ?, updated_at = ? WHERE id = ?',
        now,
        now,
        p.id,
      );
    });
    blobs.remove(coverKey(p.group_id, p.id));
    res.status(204).end();
  });

  return router;
}
