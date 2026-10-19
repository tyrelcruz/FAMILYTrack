const DEV_SECRET = 'dev-only-secret-change-me';

export const config = {
  port: Number(process.env.PORT ?? 3000),
  jwtSecret: process.env.JWT_SECRET ?? DEV_SECRET,
  databasePath: process.env.DATABASE_PATH ?? 'data/familytrack.db',
  tokenTtl: '30d',
} as const;

if (process.env.NODE_ENV === 'production' && config.jwtSecret === DEV_SECRET) {
  throw new Error('Set JWT_SECRET before running in production.');
}
