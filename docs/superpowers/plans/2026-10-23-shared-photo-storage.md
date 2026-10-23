# Shared Photo Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Photos (receipts today, plan covers next) are kept on the phone for speed and offline use, and on the server so every family member sees the same picture.

**Architecture:** Local-first, server-as-source-of-truth, exactly how receipt photos already work: the phone saves the file, marks the row `photo_dirty`, and sync uploads it; other phones see `hasPhoto` in sync and download the bytes. This plan (1) puts server file access behind a small `BlobStore` interface so disk can later become S3/R2 without touching routes, and (2) reuses the receipt pattern for plan covers, replacing the phone-only `PlanCovers`.

**Tech Stack:** Express 5 + `node:sqlite` + zod (backend, `node --test` via tsx); Flutter + sqflite + `image_picker` (mobile).

**Spec:** None written; this plan implements the decision below.

## Decision: where photos live

| Option | Verdict |
|---|---|
| Phone only | No. Shared plans/entries would show different pictures per person; reinstall loses them. Keep only as the offline cache. |
| Phone cache + server disk (`photos/` next to the SQLite file) | **Do now.** Already built for receipts, no new service, fine for a family-sized app. Needs the server disk to be persistent and backed up. |
| Phone cache + object storage (S3 / R2 / Supabase) | **Do when** the server moves to ephemeral or multi-instance hosting, or photos pass a few GB. The `BlobStore` interface in Task 1 makes this a one-file change. |

Not chosen: storing image bytes in SQLite (bloats the DB and its backups), and phones uploading straight to object storage with signed URLs (more moving parts than a family app needs).

## Global Constraints

- Images only: JPEG, PNG, WebP or HEIC, sniffed from the bytes, never from the declared type.
- Upload limit stays 6 MB; phones shrink to 1600px at quality 80 before upload (`receipt_photo.dart`).
- Files are scoped per group: `<photosDir>/<groupId>/…`; every route checks group membership through the existing `inGroup` middleware.
- Sync protocol unchanged: photo state travels as a `hasPhoto`-style boolean on the row; bytes move through separate endpoints.
- Offline must keep working: a failed upload leaves `photo_dirty = 1` and retries on the next sync.

## Review Focus

- Two phones set a cover at the same time: last write wins, both end with the same file after the next sync.
- Plan deleted while its cover is on disk: the file is removed with the plan, not orphaned.
- Someone not in the family requests `/plans/:id/cover`: 403/404, never the bytes.
- Non-image bytes sent to the cover endpoint: 400, nothing written.
- Cover set offline, then phone goes online: uploads once, `photo_dirty` cleared, no duplicate downloads.

---

### Task 1: `BlobStore` on the backend

**Files:**
- Create: `backend/src/lib/blob-store.ts`
- Modify: `backend/src/app.ts` (build the store from `photosDir`, pass it instead of the raw path), `backend/src/routes/transactions.ts:229-285` (use it)
- Test: `backend/test/api.test.ts` (existing receipt test must still pass)

**Interfaces:**
- Produces: `interface BlobStore { put(key: string, bytes: Buffer): void; path(key: string): string | null; remove(key: string): void }` and `diskBlobStore(dir: string): BlobStore`. Keys are `"<groupId>/<kind>/<id>"` (e.g. `g1/receipts/t1`); `path` returns an absolute file path when it exists, else null.
- Produces: `looksLikeImage(bytes: Buffer): boolean`, moved out of the route.

- [ ] **Step 1: Add tests in `backend/test/api.test.ts`:** `looksLikeImage` accepts JPEG/PNG/WebP/HEIC headers and rejects `Buffer.from('hello world!!')`; `diskBlobStore` round-trips put → path → remove and returns null after remove; a key containing `..` throws.
- [ ] **Step 2: Run `npm test` in `backend/`; expect the new tests to FAIL (module missing).**
- [ ] **Step 3: Implement `blob-store.ts`.** Validate keys against `/^[\w-]+(\/[\w-]+)*$/` so a key can never escape `dir`; `put` creates parent folders.
- [ ] **Step 4: Switch `transactions.ts` to the store** (`photoFile` helper and the inline sniffing go away; behavior and status codes unchanged). `createApp` keeps its `photosDir` parameter and wraps it.
- [ ] **Step 5: `npm test` and `npm run typecheck`; expect all PASS, including `stores a receipt photo per transaction`.**
- [ ] **Step 6: Commit** `refactor(backend): put photo files behind BlobStore`.

### Task 2: Plan cover endpoints

**Files:**
- Modify: `backend/src/db/migrations.ts` (append a migration), `backend/src/lib/models.ts` (`PlanRow.has_cover`, `planJson.hasCover`), `backend/src/routes/plans.ts`, `backend/src/app.ts` (pass the store to `planRoutes`)
- Test: `backend/test/api.test.ts`

**Interfaces:**
- Consumes: `BlobStore`, `looksLikeImage` from Task 1.
- Produces: `PUT|GET|DELETE /groups/:groupId/plans/:planId/cover` (same contract as the receipt endpoints: PUT raw bytes, 204; GET `image/jpeg`; DELETE 204). `planJson` gains `hasCover: boolean`. Setting or removing a cover bumps the plan's `updated_at` so sync carries `hasCover` to everyone.
- Migration: `ALTER TABLE plans ADD COLUMN has_cover INTEGER NOT NULL DEFAULT 0;`

- [ ] **Step 1: Write tests:** `stores a cover per plan` (PUT then GET returns the bytes, sync shows `hasCover: true`, DELETE flips it false and GET is 404); `rejects a non-image cover` (400, `hasCover` stays false); `hides covers from outsiders` (user in another group gets 403/404); `deleting a plan removes its cover file` (`path` is null afterwards).
- [ ] **Step 2: Run `npm test`; expect those four to FAIL (404 route).**
- [ ] **Step 3: Implement the migration, model fields and three routes in `plans.ts`.** Key is `${groupId}/covers/${planId}`; plan soft-delete also calls `remove`.
- [ ] **Step 4: Update `backend/README.md` endpoint table with the cover route.**
- [ ] **Step 5: `npm test`; expect PASS.**
- [ ] **Step 6: Commit** `feat(backend): shared plan cover photos`.

### Task 3: Phone stores and syncs the cover

**Files:**
- Modify: `mobile/lib/core/data/app_database.dart` (new DB version; `plans` gains `has_cover INTEGER NOT NULL DEFAULT 0`, `cover_path TEXT`, `cover_dirty INTEGER NOT NULL DEFAULT 0`), `mobile/lib/features/plans/models/plan.dart` (`coverPath`, `hasCover`; `toMap`/`fromMap`, not `toJson`), `mobile/lib/core/data/photo_store.dart` (generalise by folder), `mobile/lib/features/sync/sync_service.dart` (push and pull covers beside `_pushPhotos` / `_syncPhotoFiles`), `mobile/lib/features/plans/providers/plan_provider.dart` (`setCover(String planId, File photo)`, `removeCover(String planId)`)
- Delete: `mobile/lib/features/plans/widgets/plan_cover.dart`
- Modify: `plan_scene.dart` (read `plan.coverPath`, keep the painted fallback and `errorBuilder`), `plan_detail_screen.dart` (`_changeCover` calls the provider)
- Test: `mobile/test/sync_integration_test.dart`, `mobile/test/database_migration_test.dart`

**Interfaces:**
- Consumes: the endpoints from Task 2.
- Produces: `PhotoStore.save/saveBytes/delete/prune` take a `folder` argument (`'receipts'` | `'covers'`) so one class serves both; existing call sites pass `'receipts'`. `PlanProvider.setCover(String planId, File photo) -> Future<void>` saves the file, sets `cover_dirty = 1`, calls `onLocalChange` so sync runs.

- [ ] **Step 1: Write tests.** Migration: a v-previous database upgrades and old plans read `hasCover == false`. Sync: cover set locally uploads on sync and clears `cover_dirty`; a plan arriving with `hasCover: true` and no local file downloads it and sets `cover_path`; arriving with `hasCover: false` deletes the local file.
- [ ] **Step 2: Run `flutter test`; expect the new tests to FAIL.**
- [ ] **Step 3: Implement DB migration, model fields, `PhotoStore` folder argument and the two sync passes** by mirroring the receipt code path; add the plan sync-in mapping for `hasCover`.
- [ ] **Step 4: Wire `PlanProvider` and the UI; delete `PlanCovers`.** One-time carry-over: on first launch, existing `plan_covers/*` files are imported via `setCover` then removed, so nobody loses a cover picked before this change.
- [ ] **Step 5: `flutter analyze lib` clean and `flutter test` PASS.**
- [ ] **Step 6: Manual check on two devices in one family:** set a cover on A, sync both, B shows it; remove on B, A drops it after sync.
- [ ] **Step 7: Commit** `feat(mobile): sync plan cover photos`.

## Deployment note (not a task)

Photos live in `photos/` beside `DATABASE_PATH`. Wherever the backend runs, that folder must sit on a persistent volume and be included in whatever backs up the database. If hosting can't give a persistent disk, do the `BlobStore` S3/R2 implementation first; it is one new `BlobStore` plus a config switch.

## Later (out of scope)

Avatars/profile photos reuse Tasks 1–3 unchanged: a `users.has_avatar` column, `/me/avatar` endpoints, and one more folder in `PhotoStore`.

---

**Self-review:** decision covered (table); each task ends with a testable deliverable; `BlobStore`, `looksLikeImage`, `hasCover`, `PhotoStore` folder argument and `setCover` are named identically across tasks; no task code beyond signatures and test names.
