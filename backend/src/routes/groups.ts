import { Router } from 'express';
import { z } from 'zod';

import { logActivity } from '../db/activity.js';
import { many, one, run, transaction, type Db } from '../db/database.js';
import { HttpError, notFound } from '../lib/http.js';
import { newId, newInviteCode, paletteColor } from '../lib/ids.js';
import {
  groupJson,
  memberJson,
  type GroupRow,
  type MemberRow,
  type UserRow,
} from '../lib/models.js';
import {
  assertOwner,
  currentMember,
  currentUserId,
  requireGroupMember,
} from '../middleware/auth.js';
import { colorSchema, insertMember, removeMember } from '../db/members.js';

const createBody = z.object({
  name: z.string().trim().min(1).max(80),
  color: colorSchema.optional(),
});

const joinBody = z.object({
  inviteCode: z.string().trim().toUpperCase(),
  color: colorSchema.optional(),
});

const renameBody = z.object({ name: z.string().trim().min(1).max(80) });

/** Group lifecycle: create, join by invite code, rename, leave, delete. */
export function groupRoutes(db: Db) {
  const router = Router();
  const member = requireGroupMember(db);

  const userName = (userId: string) =>
    one<UserRow>(db, 'SELECT * FROM users WHERE id = ?', userId)?.name ?? 'Me';

  const activeMembers = (groupId: string) =>
    many<MemberRow>(
      db,
      `SELECT * FROM members WHERE group_id = ? AND deleted_at IS NULL
       ORDER BY role = 'owner' DESC, created_at`,
      groupId,
    );

  const uniqueInviteCode = () => {
    let code: string;
    do code = newInviteCode();
    while (one(db, 'SELECT 1 FROM groups WHERE invite_code = ?', code));
    return code;
  };

  router.post('/groups', (req, res) => {
    const body = createBody.parse(req.body);
    const userId = currentUserId(res);
    const now = Date.now();
    const group: GroupRow = {
      id: newId(),
      name: body.name,
      invite_code: uniqueInviteCode(),
      owner_id: userId,
      created_at: now,
      updated_at: now,
    };
    const owner: MemberRow = {
      id: newId(),
      group_id: group.id,
      user_id: userId,
      name: userName(userId),
      color: body.color ?? paletteColor(0),
      role: 'owner',
      created_at: now,
      updated_at: now,
      deleted_at: null,
    };
    transaction(db, () => {
      run(
        db,
        `INSERT INTO groups (id, name, invite_code, owner_id, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)`,
        group.id,
        group.name,
        group.invite_code,
        group.owner_id,
        group.created_at,
        group.updated_at,
      );
      insertMember(db, owner);
    });
    res.status(201).json({ group: groupJson(group), member: memberJson(owner) });
  });

  router.post('/groups/join', (req, res) => {
    const body = joinBody.parse(req.body);
    const userId = currentUserId(res);
    const group = one<GroupRow>(
      db,
      'SELECT * FROM groups WHERE invite_code = ?',
      body.inviteCode,
    );
    if (!group) throw notFound('Invite code');

    const existing = activeMembers(group.id).find((m) => m.user_id === userId);
    if (existing) {
      res.json({ group: groupJson(group), member: memberJson(existing) });
      return;
    }
    const now = Date.now();
    const joined: MemberRow = {
      id: newId(),
      group_id: group.id,
      user_id: userId,
      name: userName(userId),
      color: body.color ?? paletteColor(activeMembers(group.id).length),
      role: 'member',
      created_at: now,
      updated_at: now,
      deleted_at: null,
    };
    insertMember(db, joined);
    res.locals.member = joined;
    logActivity(db, res, 'member_joined', { memberId: joined.id, name: joined.name });
    res.status(201).json({ group: groupJson(group), member: memberJson(joined) });
  });

  router.get('/groups/:groupId', member, (_req, res) => {
    const { group_id } = currentMember(res);
    const group = one<GroupRow>(db, 'SELECT * FROM groups WHERE id = ?', group_id)!;
    res.json({
      group: groupJson(group),
      members: activeMembers(group_id).map(memberJson),
    });
  });

  router.patch('/groups/:groupId', member, (req, res) => {
    assertOwner(res);
    const { name } = renameBody.parse(req.body);
    const { group_id } = currentMember(res);
    run(
      db,
      'UPDATE groups SET name = ?, updated_at = ? WHERE id = ?',
      name,
      Date.now(),
      group_id,
    );
    const group = one<GroupRow>(db, 'SELECT * FROM groups WHERE id = ?', group_id)!;
    res.json({ group: groupJson(group) });
  });

  /** Issues a new invite code; the old one stops working. */
  router.post('/groups/:groupId/invite-code', member, (_req, res) => {
    assertOwner(res);
    const { group_id } = currentMember(res);
    const code = uniqueInviteCode();
    run(
      db,
      'UPDATE groups SET invite_code = ?, updated_at = ? WHERE id = ?',
      code,
      Date.now(),
      group_id,
    );
    res.json({ inviteCode: code });
  });

  router.post('/groups/:groupId/leave', member, (_req, res) => {
    const me = currentMember(res);
    if (me.role === 'owner') {
      throw new HttpError(409, 'The owner can’t leave; delete the group instead');
    }
    removeMember(db, me);
    res.status(204).end();
  });

  router.delete('/groups/:groupId', member, (_req, res) => {
    assertOwner(res);
    run(db, 'DELETE FROM groups WHERE id = ?', currentMember(res).group_id);
    res.status(204).end();
  });

  return router;
}
