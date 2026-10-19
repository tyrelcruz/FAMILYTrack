import bcrypt from 'bcryptjs';
import { Router } from 'express';
import { z } from 'zod';

import { many, one, run, type Db } from '../db/database.js';
import { HttpError } from '../lib/http.js';
import { newId } from '../lib/ids.js';
import { userJson, type GroupRow, type MemberRow, type UserRow } from '../lib/models.js';
import { currentUserId, requireAuth, signToken } from '../middleware/auth.js';

const registerBody = z.object({
  name: z.string().trim().min(1).max(80),
  email: z.email().trim().toLowerCase(),
  password: z.string().min(8).max(200),
});

const loginBody = z.object({
  email: z.string().trim().toLowerCase(),
  password: z.string(),
});

export function authRoutes(db: Db) {
  const router = Router();

  router.post('/auth/register', async (req, res) => {
    const body = registerBody.parse(req.body);
    if (one(db, 'SELECT 1 FROM users WHERE email = ?', body.email)) {
      throw new HttpError(409, 'An account with that email already exists');
    }
    const user: UserRow = {
      id: newId(),
      name: body.name,
      email: body.email,
      password_hash: await bcrypt.hash(body.password, 10),
      created_at: Date.now(),
    };
    run(
      db,
      'INSERT INTO users (id, name, email, password_hash, created_at) VALUES (?, ?, ?, ?, ?)',
      user.id,
      user.name,
      user.email,
      user.password_hash,
      user.created_at,
    );
    res.status(201).json({ token: signToken(user.id), user: userJson(user) });
  });

  router.post('/auth/login', async (req, res) => {
    const body = loginBody.parse(req.body);
    const user = one<UserRow>(db, 'SELECT * FROM users WHERE email = ?', body.email);
    const ok = user && (await bcrypt.compare(body.password, user.password_hash));
    if (!user || !ok) throw new HttpError(401, 'Wrong email or password');
    res.json({ token: signToken(user.id), user: userJson(user) });
  });

  /** The signed-in user and the family groups they belong to. */
  router.get('/me', requireAuth, (_req, res) => {
    const userId = currentUserId(res);
    const user = one<UserRow>(db, 'SELECT * FROM users WHERE id = ?', userId);
    if (!user) throw new HttpError(401, 'Sign in required');
    const groups = many<GroupRow & Pick<MemberRow, 'role'> & { member_id: string }>(
      db,
      `SELECT g.*, m.role, m.id AS member_id
       FROM groups g JOIN members m ON m.group_id = g.id
       WHERE m.user_id = ? AND m.deleted_at IS NULL
       ORDER BY g.created_at`,
      userId,
    );
    res.json({
      user: userJson(user),
      groups: groups.map((g) => ({
        id: g.id,
        name: g.name,
        role: g.role,
        memberId: g.member_id,
      })),
    });
  });

  return router;
}
