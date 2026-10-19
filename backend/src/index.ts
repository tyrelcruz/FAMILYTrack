import { createApp } from './app.js';
import { config } from './config.js';
import { openDatabase } from './db/database.js';

const db = openDatabase(config.databasePath);
const server = createApp(db).listen(config.port, () => {
  console.log(`FamilyTrack API listening on http://localhost:${config.port}`);
});

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    server.close(() => {
      db.close();
      process.exit(0);
    });
  });
}
