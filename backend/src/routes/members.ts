import { Router } from 'express';
import { z } from 'zod';

import { logActivity } from '../db/activity.js';
import { many, one, run, type Db } from '../db/database.js';
import { forbidden, HttpError, notFound } from '../lib/http.js';
import { newId, paletteColor } from '../lib/ids.js';
import { memberJson, type MemberRow } from '../lib/models.js';
import { assertOwner, currentMember } from '../middleware/auth.js';
import { colorSchema, insertMember, removeMember } from '../db/members.js';

const createBody = z.object({
  // Clients may pick the id so records made offline keep it after syncing.
  id: z.uuid().optional(),
  name: z.string().trim().min(1).max(80),
  color: colorSchema.optional(),
});

const updateBody = z.object({
  name: z.string().trim().min(1).max(80).optional(),
  color: colorSchema.optional(),
});

/** Mounted under /groups/:groupId/members. */
export function memberRoutes(db: Db) {
  const router = Router({ mergeParams: true });

  const find = (groupId: string, id: string) => {
    const m = one<MemberRow>(
      db,
      'SELECT * FROM members WHERE id = ? AND group_id = ? AND deleted_at IS NULL',
      id,
      groupId,
    );
    if (!m) throw notFound('Member');
    return m;
  };

  router.get('/', (_req, res) => {
    const members = many<MemberRow>(
      db,
      `SELECT * FROM members WHERE group_id = ? AND deleted_at IS NULL
       ORDER BY role = 'owner' DESC, created_at`,
      currentMember(res).group_id,
    );
    res.json({ members: members.map(memberJson) });
  });

  /** Adds someone without an account, e.g. a child. */
  router.post('/', (req, res) => {
    const body = createBody.parse(req.body);
    const groupId = currentMember(res).group_id;
    if (body.id && one(db, 'SELECT 1 FROM members WHERE id = ?', body.id)) {
      throw new HttpError(409, 'A member with that id already exists');
    }
    const count = one<{ n: number }>(
      db,
      'SELECT COUNT(*) AS n FROM members WHERE group_id = ? AND deleted_at IS NULL',
      groupId,
    )!.n;
    const now = Date.now();
    const m: MemberRow = {
      id: body.id ?? newId(),
      group_id: groupId,
      user_id: null,
      name: body.name,
      color: body.color ?? paletteColor(count),
      role: 'member',
      created_at: now,
      updated_at: now,
      deleted_at: null,
    };
    insertMember(db, m);
    logActivity(db, res, 'member_added', { memberId: m.id, name: m.name });
    res.status(201).json({ member: memberJson(m) });
  });

  /** The owner can edit anyone; others only themselves. */
  router.patch('/:memberId', (req, res) => {
    const body = updateBody.parse(req.body);
    const me = currentMember(res);
    const m = find(me.group_id, String(req.params.memberId));
    if (me.role !== 'owner' && m.id !== me.id) throw forbidden();
    const updated: MemberRow = {
      ...m,
      name: body.name ?? m.name,
      color: body.color ?? m.color,
      updated_at: Date.now(),
    };
    run(
      db,
      'UPDATE members SET name = ?, color = ?, updated_at = ? WHERE id = ?',
      updated.name,
      updated.color,
      updated.updated_at,
      m.id,
    );
    res.json({ member: memberJson(updated) });
  });

  router.delete('/:memberId', (req, res) => {
    assertOwner(res);
    const m = find(currentMember(res).group_id, String(req.params.memberId));
    if (m.role === 'owner') throw new HttpError(409, 'The owner can’t be removed');
    removeMember(db, m);
    res.status(204).end();
  });

  return router;
}
