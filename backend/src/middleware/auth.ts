import type { RequestHandler, Response } from 'express';
import jwt from 'jsonwebtoken';

import { config } from '../config.js';
import { one, type Db } from '../db/database.js';
import { forbidden, HttpError, notFound } from '../lib/http.js';
import type { MemberRow } from '../lib/models.js';

export function signToken(userId: string): string {
  return jwt.sign({}, config.jwtSecret, {
    subject: userId,
    expiresIn: config.tokenTtl,
  });
}

/** Requires `Authorization: Bearer <token>`; sets `res.locals.userId`. */
export const requireAuth: RequestHandler = (req, res, next) => {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  try {
    const payload = jwt.verify(token, config.jwtSecret);
    if (typeof payload === 'string' || !payload.sub) throw new Error();
    res.locals.userId = payload.sub;
    next();
  } catch {
    next(new HttpError(401, 'Sign in required'));
  }
};

export const currentUserId = (res: Response): string => res.locals.userId;

/**
 * Requires the signed-in user to belong to `:groupId`; sets
 * `res.locals.member` to their membership. Non-members get a 404 so group
 * ids can't be probed.
 */
export const requireGroupMember =
  (db: Db): RequestHandler =>
  (req, res, next) => {
    const member = one<MemberRow>(
      db,
      `SELECT * FROM members
       WHERE group_id = ? AND user_id = ? AND deleted_at IS NULL`,
      String(req.params.groupId),
      currentUserId(res),
    );
    if (!member) return next(notFound('Group'));
    res.locals.member = member;
    next();
  };

export const currentMember = (res: Response): MemberRow => res.locals.member;

export function assertOwner(res: Response) {
  if (currentMember(res).role !== 'owner') {
    throw forbidden('Only the group owner can do that');
  }
}
