import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import cors from 'cors';
import express from 'express';

import type { Db } from './db/database.js';
import { errorHandler, unknownRoute } from './lib/http.js';
import { requireAuth, requireGroupMember } from './middleware/auth.js';
import { authRoutes } from './routes/auth.js';
import { budgetRoutes } from './routes/budgets.js';
import { groupRoutes } from './routes/groups.js';
import { memberRoutes } from './routes/members.js';
import { planRoutes } from './routes/plans.js';
import { syncRoutes } from './routes/sync.js';
import { transactionRoutes } from './routes/transactions.js';
import { transferRoutes } from './routes/transfers.js';

export function createApp(
  db: Db,
  // Where receipt photos are kept; a throwaway folder unless given.
  photosDir: string = mkdtempSync(join(tmpdir(), 'familytrack-photos-')),
) {
  const app = express();
  app.disable('x-powered-by');
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });

  const api = express.Router();
  api.use(authRoutes(db));
  api.use(requireAuth);
  api.use(groupRoutes(db));

  const inGroup = requireGroupMember(db);
  api.use('/groups/:groupId/members', inGroup, memberRoutes(db));
  api.use('/groups/:groupId/transactions', inGroup, transactionRoutes(db, photosDir));
  api.use('/groups/:groupId/budgets', inGroup, budgetRoutes(db));
  api.use('/groups/:groupId/plans', inGroup, planRoutes(db));
  api.use('/groups/:groupId/transfers', inGroup, transferRoutes(db));
  api.use('/groups/:groupId/sync', inGroup, syncRoutes(db));

  app.use('/api', api);
  app.use(unknownRoute);
  app.use(errorHandler);
  return app;
}
