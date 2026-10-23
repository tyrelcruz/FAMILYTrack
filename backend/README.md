# FamilyTrack API

Keeps a family group's members, spending and budgets in sync across phones.

- Node.js ≥ 22.13, Express 5, TypeScript, Zod
- SQLite via Node's built-in `node:sqlite` (file at `DATABASE_PATH`)
- JWT auth (`Authorization: Bearer <token>`), passwords hashed with bcrypt

## Scripts

| Command | What it does |
| --- | --- |
| `npm run dev` | Start with reload on http://localhost:3001 |
| `npm test` | End-to-end API tests on an in-memory database |
| `npm run build` / `npm start` | Compile to `dist/` and run it |
| `npm run typecheck` | Type-check only |

Environment (see `.env.example`): `PORT`, `JWT_SECRET` (required when
`NODE_ENV=production`), `DATABASE_PATH`.

## Data model

- **Group**: one family. Has an `inviteCode` others use to join.
- **Member**: a person in a group. Members who signed up have a `userId`;
  members without an account (e.g. kids) have `userId: null`. One owner per group.
- **Transaction**: income or expense, optionally tied to a `memberId`
  (`null` = the owner). Same fields as the app: `title`, `amount`, `type`,
  `categoryId`, `date` (ms), `note`.
- **Budget**: monthly `limit` per `categoryId`, or `overall` for the whole family.
- **Plan**: a budget for a `trip` or a `monthly` period (`startDate`–`endDate`).
  `funds` says where the money is (`cash`, `ewallet`, `card`, `bank`);
  `shares` divides it between members (`{memberId: amount}`), `split` is
  `equal` or `custom`. Transactions join a plan with `planId` and record
  `paymentMethod`.
- **Transfer**: money moved without being spent — `kind: "wallet"` between
  two `fromMethod`/`toMethod`, or `kind: "people"` from `fromMemberId` to
  `toMemberId`. Optional `planId`. Never counts as income or expense.
- **Activity**: append-only feed of what members did (expense added, member
  joined, plan created, budget set, transfer added), for notifications.
  Expenses dated more than 3 days away aren't logged, so bulk uploads don't
  flood it.

All ids are UUIDs. Clients may send their own `id` when creating members or
transactions, so records made offline keep their id after upload.

## Endpoints

All under `/api`. Everything except register/login needs a token.
Group routes return 404 to anyone outside the group.

| Method | Path | Notes |
| --- | --- | --- |
| POST | `/auth/register` | `{name, email, password}` → `{token, user}` |
| POST | `/auth/login` | `{email, password}` → `{token, user}` |
| GET | `/me` | User + groups they belong to |
| POST | `/groups` | `{name, color?}` → creates group, you become owner |
| POST | `/groups/join` | `{inviteCode, color?}` |
| GET | `/groups/:groupId` | Group, invite code, members |
| PATCH | `/groups/:groupId` | `{name}` (owner) |
| POST | `/groups/:groupId/invite-code` | New code; old one stops working (owner) |
| POST | `/groups/:groupId/leave` | Non-owners only |
| DELETE | `/groups/:groupId` | Deletes everything in it (owner) |
| GET / POST | `/groups/:groupId/members` | Add a member without an account: `{name, color?, id?}` |
| PATCH / DELETE | `/groups/:groupId/members/:memberId` | Owner edits anyone, others only themselves. Removing moves their transactions to the owner. |
| GET | `/groups/:groupId/transactions?month=2026-10` | `month` optional (UTC bounds) |
| POST | `/groups/:groupId/transactions` | `{title, amount, type, categoryId, date, note?, memberId?, planId?, paymentMethod?, id?}` |
| PATCH / DELETE | `/groups/:groupId/transactions/:id` | Partial update / soft delete |
| PUT / GET / DELETE | `/groups/:groupId/transactions/:id/photo` | Receipt photo: PUT the image bytes (JPEG/PNG/WebP/HEIC, up to 6 MB); `hasPhoto` shows in sync. Files live in `photos/` next to the database. |
| PUT / GET / DELETE | `/groups/:groupId/plans/:id/cover` | Plan cover photo, same rules as receipts; `hasCover` shows in sync. Files live in `photos/<groupId>/covers/`. |
| GET | `/groups/:groupId/budgets` | |
| PUT / DELETE | `/groups/:groupId/budgets/:categoryId` | `{limit}`; `categoryId` may be `overall` |
| GET / POST | `/groups/:groupId/plans` | `{name, kind, startDate, endDate, funds, shares, split, id?}` |
| PATCH / DELETE | `/groups/:groupId/plans/:planId` | Deleting keeps its expenses (their `planId` becomes null) |
| GET / POST | `/groups/:groupId/transfers` | `{kind, amount, fromMethod?, toMethod?, fromMemberId?, toMemberId?, planId?, note?, date, id?}` |
| PATCH / DELETE | `/groups/:groupId/transfers/:transferId` | |
| GET | `/groups/:groupId/sync?since=<ms>` | Everything changed since `since`: members, plans, transactions, budgets, transfers, and up to 200 `activity` items |

## Syncing

1. First sync: `GET /groups/:id/sync` (no `since`) to download everything.
2. Save `serverTime` from the response.
3. Push local changes with the normal POST/PATCH/PUT/DELETE calls.
4. Next sync: `GET /groups/:id/sync?since=<saved serverTime>`.
   Apply each row as an upsert by `id`; rows with `deleted: true` are removed.

Errors are `{error}` JSON; validation errors also include `issues: [{path, message}]`.
