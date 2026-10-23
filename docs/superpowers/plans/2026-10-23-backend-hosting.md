# Backend Hosting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The FamilyTrack API runs on a public HTTPS URL with a persistent disk, so every phone in a family can sync and see shared photos.

**Architecture:** One Node process serving Express over a single SQLite file; photos sit in a `photos/` folder next to that file (`dirname(DATABASE_PATH)/photos`). So the whole server state is one folder, and hosting means "run Node + mount one persistent volume at that folder + HTTPS".

**Tech Stack:** Node ≥ 22.13 (needs built-in `node:sqlite`), Docker, Railway (recommended host).

**Spec:** None; this plan implements the decision below.

## Decision: where to host

| Option | Cost (approx.) | Fit |
|---|---|---|
| **Railway** + 1 volume | ~$5/mo | **Recommended.** Deploys from GitHub or a Dockerfile, volumes are a click, HTTPS URL included, no server admin. |
| Fly.io + volume | ~$2–5/mo | Equally valid and slightly cheaper; more CLI work (`fly launch`, volumes, one machine only). |
| VPS (Hetzner / DigitalOcean) | ~$4–6/mo | Cheapest per GB and most control; you maintain the OS, Docker, HTTPS (Caddy) and backups. |
| Render free / Heroku / serverless (Vercel, Lambda) | free–cheap | **Avoid.** Disk is wiped on restart, so the database and every photo vanish. SQLite needs a disk that lasts. |

Run **exactly one instance** on any host: SQLite is a single-writer file and cannot be shared across machines.

## Global Constraints

- Node ≥ 22.13 in the image (`engines` in `backend/package.json`).
- `NODE_ENV=production` and `JWT_SECRET` set to a long random value; the server refuses to start otherwise (`backend/src/config.ts`).
- `DATABASE_PATH` points inside the mounted volume, e.g. `/data/familytrack.db`; photos then land in `/data/photos` automatically.
- The app talks to the server over HTTPS only once it is public.
- One instance, no autoscaling.

## Review Focus

- Redeploy or restart: the database and `photos/` survive (volume, not container disk).
- Missing or default `JWT_SECRET`: deploy fails loudly instead of running insecure.
- Volume full: uploads fail with a clear error rather than corrupting the database.
- A phone still pointing at `localhost`: shows the offline banner, never crashes; server address can be changed in Profile → App.
- Backups: a restore from a copy of `/data` brings back accounts, plans and photos together.

---

### Task 1: Container image

**Files:**
- Create: `backend/Dockerfile`, `backend/.dockerignore`
- Test: manual build and run

**Interfaces:**
- Produces: an image that serves `GET /health` → `{"ok":true}` on `$PORT` and reads `DATABASE_PATH`, `JWT_SECRET`.

- [ ] **Step 1: Write `Dockerfile`:** base `node:22-slim`, `npm ci`, `npm run build`, `CMD ["npm","start"]`; `.dockerignore` excludes `node_modules`, `dist`, `data`, `.env`.
- [ ] **Step 2: Build and run locally with a mounted folder:**
  `docker build -t familytrack-api backend && docker run -p 3001:3001 -e PORT=3001 -e NODE_ENV=production -e JWT_SECRET=$(openssl rand -hex 32) -e DATABASE_PATH=/data/familytrack.db -v ft-data:/data familytrack-api`
- [ ] **Step 3: Verify:** `curl localhost:3001/health` prints `{"ok":true}`; stopping and re-running the container keeps a registered account (volume works).
- [ ] **Step 4: Commit** `chore(backend): add Dockerfile`.

### Task 2: Deploy to Railway

**Files:** none (hosting configuration); record the steps in `backend/README.md` under "Deploying".

**Interfaces:**
- Consumes: the image from Task 1.
- Produces: a public URL `https://<name>.up.railway.app` serving `/health`.

- [ ] **Step 1: Create a Railway project from the GitHub repo, root directory `backend`, builder Dockerfile.**
- [ ] **Step 2: Add a volume mounted at `/data`.**
- [ ] **Step 3: Set variables:** `NODE_ENV=production`, `JWT_SECRET=<openssl rand -hex 32>`, `DATABASE_PATH=/data/familytrack.db`; leave `PORT` to Railway.
- [ ] **Step 4: Generate a public domain and verify** `curl https://<url>/health` returns `{"ok":true}`.
- [ ] **Step 5: Redeploy once and confirm data persists** (register, redeploy, log in again).
- [ ] **Step 6: Commit the README deploy notes** `docs(backend): deployment steps`.

### Task 3: Point the app at it

**Files:**
- Modify: none for testing (server address row in Profile → App); for release builds run with `--dart-define=API_URL=https://<url>/api`.
- Test: two physical phones.

- [ ] **Step 1: On phone A, Profile → App → Server address, enter `https://<url>/api`, sign up and create a family.**
- [ ] **Step 2: On phone B, same address, sign up and join with A's invite code.**
- [ ] **Step 3: Verify sharing:** add an entry with a receipt photo and set a plan cover on A; after a sync both appear on B.
- [ ] **Step 4: Release builds:** build with `--dart-define=API_URL=https://<url>/api` so users never type the address.

### Task 4: Backups

**Files:** none (Railway scheduled job or a copy of the volume).

- [ ] **Step 1: Take a snapshot of `/data` (database plus `photos/`) on a schedule, daily is enough.** Railway: volume backups; VPS: nightly `sqlite3 familytrack.db ".backup"` plus `rsync photos/` to storage elsewhere.
- [ ] **Step 2: Test a restore into a fresh volume and confirm login and a photo still work.**

---

## When to revisit

If the host cannot give a persistent disk, or photos pass a few GB, add an S3/R2 `BlobStore` (one file; routes unchanged). If you outgrow one instance, SQLite → Postgres is the bigger change.

**Self-review:** decision covers the three real contenders and what to avoid; every task ends in a checkable result; env names match `config.ts`; photo location follows `dirname(DATABASE_PATH)`, so one volume covers both.
