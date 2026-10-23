import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import { after, before, describe, it } from 'node:test';

import { createApp } from '../src/app.js';
import { openDatabase } from '../src/db/database.js';
import { diskBlobStore, looksLikeImage } from '../src/lib/blob-store.js';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

let base = '';
let close: () => void;

before(async () => {
  const server = createApp(openDatabase(':memory:')).listen(0);
  await new Promise((r) => server.once('listening', r));
  base = `http://localhost:${(server.address() as AddressInfo).port}/api`;
  close = () => server.close();
});
after(() => close());

async function call(method: string, path: string, token?: string, body?: unknown) {
  const res = await fetch(base + path, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

async function register(name: string) {
  const res = await call('POST', '/auth/register', undefined, {
    name,
    email: `${name.toLowerCase()}@example.com`,
    password: 'password123',
  });
  assert.equal(res.status, 201);
  return res.body.token as string;
}

describe('family sync API', () => {
  let owner = '';
  let partner = '';
  let groupId = '';
  let inviteCode = '';

  it('rejects requests without a token', async () => {
    assert.equal((await call('GET', '/me')).status, 401);
  });

  it('registers, logs in and blocks duplicate emails', async () => {
    owner = await register('Muminu');
    partner = await register('Ana');
    const dup = await call('POST', '/auth/register', undefined, {
      name: 'X',
      email: 'ANA@example.com',
      password: 'password123',
    });
    assert.equal(dup.status, 409);
    const bad = await call('POST', '/auth/login', undefined, {
      email: 'ana@example.com',
      password: 'wrong-password',
    });
    assert.equal(bad.status, 401);
    const ok = await call('POST', '/auth/login', undefined, {
      email: 'ana@example.com',
      password: 'password123',
    });
    assert.equal(ok.status, 200);
  });

  it('creates a group and lets a second person join by invite code', async () => {
    const created = await call('POST', '/groups', owner, { name: 'Hoque Family' });
    assert.equal(created.status, 201);
    assert.equal(created.body.member.isOwner, true);
    groupId = created.body.group.id;
    inviteCode = created.body.group.inviteCode;

    const outsider = await call('GET', `/groups/${groupId}`, partner);
    assert.equal(outsider.status, 404);

    const joined = await call('POST', '/groups/join', partner, {
      inviteCode: inviteCode.toLowerCase(),
    });
    assert.equal(joined.status, 201);
    const again = await call('POST', '/groups/join', partner, { inviteCode });
    assert.equal(again.status, 200);

    const group = await call('GET', `/groups/${groupId}`, partner);
    assert.equal(group.body.members.length, 2);
    const me = await call('GET', '/me', partner);
    assert.equal(me.body.groups[0].id, groupId);
  });

  it('syncs one member’s spending and budgets to the other', async () => {
    const start = await call('GET', `/groups/${groupId}/sync`, owner);
    const since = start.body.serverTime;
    const partnerMemberId = start.body.members.find(
      (m: { isOwner: boolean }) => !m.isOwner,
    ).id;

    const spent = await call('POST', `/groups/${groupId}/transactions`, partner, {
      title: 'Groceries',
      amount: 120,
      type: 'expense',
      categoryId: 'groceries',
      date: Date.now(),
      memberId: partnerMemberId,
    });
    assert.equal(spent.status, 201);
    const budget = await call('PUT', `/groups/${groupId}/budgets/overall`, partner, {
      limit: 3000,
    });
    assert.equal(budget.status, 200);

    const delta = await call('GET', `/groups/${groupId}/sync?since=${since}`, owner);
    assert.equal(delta.body.transactions.length, 1);
    assert.equal(delta.body.transactions[0].memberId, partnerMemberId);
    assert.equal(delta.body.budgets[0].limit, 3000);
    assert.equal(delta.body.members.length, 0);

    const del = await call(
      'DELETE',
      `/groups/${groupId}/transactions/${spent.body.transaction.id}`,
      owner,
    );
    assert.equal(del.status, 204);
    const afterDelete = await call(
      'GET',
      `/groups/${groupId}/sync?since=${delta.body.serverTime}`,
      partner,
    );
    assert.equal(afterDelete.body.transactions[0].deleted, true);
  });

  it('validates input', async () => {
    const res = await call('POST', `/groups/${groupId}/transactions`, owner, {
      title: '',
      amount: -5,
      type: 'gift',
    });
    assert.equal(res.status, 400);
    assert.ok(res.body.issues.length >= 3);
  });

  it('adds members without accounts and moves their spending to the owner when removed', async () => {
    const kid = await call('POST', `/groups/${groupId}/members`, owner, { name: 'Sam' });
    assert.equal(kid.status, 201);
    const kidId = kid.body.member.id;
    const t = await call('POST', `/groups/${groupId}/transactions`, owner, {
      title: 'School supplies',
      amount: 80,
      type: 'expense',
      categoryId: 'education',
      date: Date.now(),
      memberId: kidId,
    });

    const notOwner = await call('DELETE', `/groups/${groupId}/members/${kidId}`, partner);
    assert.equal(notOwner.status, 403);
    const removed = await call('DELETE', `/groups/${groupId}/members/${kidId}`, owner);
    assert.equal(removed.status, 204);

    const list = await call('GET', `/groups/${groupId}/transactions`, owner);
    const moved = list.body.transactions.find(
      (x: { id: string }) => x.id === t.body.transaction.id,
    );
    assert.equal(moved.memberId, null);
  });

  it('tracks a trip plan: funds, shares, and expenses by person and method', async () => {
    const members = (await call('GET', `/groups/${groupId}/members`, owner)).body.members;
    const [ownerM, partnerM] = members as { id: string; isOwner: boolean }[];
    const created = await call('POST', `/groups/${groupId}/plans`, partner, {
      name: 'Baguio trip',
      kind: 'trip',
      startDate: Date.UTC(2026, 9, 20),
      endDate: Date.UTC(2026, 9, 24),
      funds: { cash: 6000, ewallet: 4000 },
      shares: { [ownerM!.id]: 5000, [partnerM!.id]: 5000 },
      split: 'equal',
    });
    assert.equal(created.status, 201);
    const planId = created.body.plan.id;
    assert.deepEqual(created.body.plan.funds, { cash: 6000, ewallet: 4000 });

    const event = await call('POST', `/groups/${groupId}/plans`, owner, {
      name: 'Lola’s 80th',
      kind: 'event',
      startDate: Date.UTC(2026, 11, 5),
      endDate: Date.UTC(2026, 11, 5),
      funds: { cash: 8000 },
      shares: {},
      split: 'equal',
      destination: 'Tagaytay, Cavite',
      description: 'Lunch and cake',
    });
    assert.equal(event.status, 201);
    assert.equal(event.body.plan.destination, 'Tagaytay, Cavite');
    assert.equal(event.body.plan.kind, 'event');

    const bad = await call('POST', `/groups/${groupId}/plans`, owner, {
      ...created.body.plan,
      id: undefined,
      funds: { crypto: 5 },
    });
    assert.equal(bad.status, 400);

    const spend = await call('POST', `/groups/${groupId}/transactions`, owner, {
      title: 'Strawberries',
      amount: 250,
      type: 'expense',
      categoryId: 'food',
      date: Date.UTC(2026, 9, 21),
      memberId: partnerM!.id,
      planId,
      paymentMethod: 'cash',
    });
    assert.equal(spend.status, 201);
    assert.equal(spend.body.transaction.planId, planId);
    assert.equal(spend.body.transaction.paymentMethod, 'cash');

    const sync = await call('GET', `/groups/${groupId}/sync`, owner);
    assert.ok(sync.body.plans.some((p: { id: string }) => p.id === planId));

    const renamed = await call('PATCH', `/groups/${groupId}/plans/${planId}`, owner, {
      name: 'Baguio weekend',
      endDate: Date.UTC(2026, 9, 19),
    });
    assert.equal(renamed.status, 400);

    assert.equal((await call('DELETE', `/groups/${groupId}/plans/${planId}`, owner)).status, 204);
    const list = await call('GET', `/groups/${groupId}/transactions`, owner);
    const kept = list.body.transactions.find(
      (t: { id: string }) => t.id === spend.body.transaction.id,
    );
    assert.equal(kept.planId, null);
  });

  it('records transfers between wallets and people', async () => {
    const members = (await call('GET', `/groups/${groupId}/members`, owner)).body.members;
    const [a, b] = members as { id: string }[];
    const wallet = await call('POST', `/groups/${groupId}/transfers`, owner, {
      kind: 'wallet',
      amount: 1000,
      fromMethod: 'ewallet',
      toMethod: 'cash',
      date: Date.now(),
    });
    assert.equal(wallet.status, 201);
    const people = await call('POST', `/groups/${groupId}/transfers`, partner, {
      kind: 'people',
      amount: 500,
      fromMemberId: a!.id,
      toMemberId: b!.id,
      fromMethod: 'cash',
      date: Date.now(),
    });
    assert.equal(people.status, 201);
    const same = await call('POST', `/groups/${groupId}/transfers`, owner, {
      kind: 'wallet',
      amount: 10,
      fromMethod: 'cash',
      toMethod: 'cash',
      date: Date.now(),
    });
    assert.equal(same.status, 400);

    const sync = await call('GET', `/groups/${groupId}/sync`, partner);
    assert.equal(sync.body.transfers.length, 2);
    const del = await call(
      'DELETE',
      `/groups/${groupId}/transfers/${wallet.body.transfer.id}`,
      partner,
    );
    assert.equal(del.status, 204);
  });

  it('keeps an activity feed of what each person did', async () => {
    const since = Date.now();
    await call('POST', `/groups/${groupId}/transactions`, partner, {
      title: 'Halo-halo',
      amount: 120,
      type: 'expense',
      categoryId: 'food',
      date: Date.now(),
    });
    // Old entries uploaded in bulk don't make news.
    await call('POST', `/groups/${groupId}/transactions`, partner, {
      title: 'Last year',
      amount: 1,
      type: 'expense',
      categoryId: 'food',
      date: Date.now() - 400 * 24 * 60 * 60 * 1000,
    });
    const sync = await call('GET', `/groups/${groupId}/sync?since=${since}`, owner);
    const titles = sync.body.activity.map(
      (x: { data: { title?: string } }) => x.data.title,
    );
    assert.ok(titles.includes('Halo-halo'));
    assert.ok(!titles.includes('Last year'));
    const item = sync.body.activity.find(
      (x: { data: { title?: string } }) => x.data.title === 'Halo-halo',
    );
    assert.equal(item.kind, 'transaction_added');
    assert.equal(item.actorName, 'Ana');

    const full = await call('GET', `/groups/${groupId}/sync`, owner);
    const kinds = new Set(full.body.activity.map((x: { kind: string }) => x.kind));
    for (const k of ['member_joined', 'member_added', 'plan_created', 'budget_set', 'transfer_added']) {
      assert.ok(kinds.has(k), `missing ${k}`);
    }
  });

  it('stores a receipt photo per transaction', async () => {
    const t = await call('POST', `/groups/${groupId}/transactions`, owner, {
      title: 'Grocery receipt',
      amount: 300,
      type: 'expense',
      categoryId: 'groceries',
      date: Date.now(),
    });
    const id = t.body.transaction.id;
    const url = `${base}/groups/${groupId}/transactions/${id}/photo`;
    const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4, 5, 6, 7, 8]);
    const put = (body: Buffer, token = owner) =>
      fetch(url, {
        method: 'PUT',
        headers: { authorization: `Bearer ${token}`, 'content-type': 'image/jpeg' },
        body: new Uint8Array(body),
      });

    assert.equal((await put(Buffer.from('not an image at all'))).status, 400);
    assert.equal((await put(jpeg)).status, 204);

    const sync = await call('GET', `/groups/${groupId}/sync`, partner);
    const synced = sync.body.transactions.find((x: { id: string }) => x.id === id);
    assert.equal(synced.hasPhoto, true);

    const got = await fetch(url, { headers: { authorization: `Bearer ${partner}` } });
    assert.equal(got.status, 200);
    assert.deepEqual(Buffer.from(await got.arrayBuffer()), jpeg);

    const outsider = await register('Outsider');
    assert.equal(
      (await fetch(url, { headers: { authorization: `Bearer ${outsider}` } })).status,
      404,
    );

    const del = await fetch(url, {
      method: 'DELETE',
      headers: { authorization: `Bearer ${owner}` },
    });
    assert.equal(del.status, 204);
    const after = await fetch(url, { headers: { authorization: `Bearer ${owner}` } });
    assert.equal(after.status, 404);
  });

  it('recognises images by their bytes', () => {
    const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
    const webp = Buffer.concat([Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WEBP')]);
    const heic = Buffer.concat([Buffer.alloc(4), Buffer.from('ftypheic')]);
    for (const b of [Buffer.from([0xff, 0xd8, 0xff, 0xe0]), png, webp, heic]) {
      assert.equal(looksLikeImage(b), true);
    }
    assert.equal(looksLikeImage(Buffer.from('hello world!!')), false);
  });

  it('keeps blobs on disk and refuses keys that escape', () => {
    const store = diskBlobStore(mkdtempSync(join(tmpdir(), 'blobs-')));
    store.put('g1/t1', Buffer.from('x'));
    assert.ok(store.path('g1/t1'));
    store.remove('g1/t1');
    assert.equal(store.path('g1/t1'), null);
    assert.throws(() => store.put('../evil', Buffer.from('x')));
  });

  it('stores a cover per plan', async () => {
    const plan = await call('POST', `/groups/${groupId}/plans`, owner, {
      name: 'Cover trip',
      kind: 'trip',
      startDate: Date.now(),
      endDate: Date.now() + 86400000,
      funds: { cash: 100 },
      shares: {},
      split: 'equal',
    });
    const id = plan.body.plan.id;
    const url = `${base}/groups/${groupId}/plans/${id}/cover`;
    const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4, 5, 6, 7, 8]);
    const put = (body: Buffer) =>
      fetch(url, {
        method: 'PUT',
        headers: { authorization: `Bearer ${owner}`, 'content-type': 'image/jpeg' },
        body: new Uint8Array(body),
      });
    const hasCover = async () => {
      const sync = await call('GET', `/groups/${groupId}/sync`, partner);
      return sync.body.plans.find((x: { id: string }) => x.id === id).hasCover;
    };

    assert.equal((await put(Buffer.from('not an image at all'))).status, 400);
    assert.equal(await hasCover(), false);
    assert.equal((await put(jpeg)).status, 204);
    assert.equal(await hasCover(), true);

    const got = await fetch(url, { headers: { authorization: `Bearer ${partner}` } });
    assert.equal(got.status, 200);
    assert.deepEqual(Buffer.from(await got.arrayBuffer()), jpeg);

    const outsider = await register('Coverstranger');
    assert.equal(
      (await fetch(url, { headers: { authorization: `Bearer ${outsider}` } })).status,
      404,
    );

    const del = await fetch(url, {
      method: 'DELETE',
      headers: { authorization: `Bearer ${owner}` },
    });
    assert.equal(del.status, 204);
    assert.equal(await hasCover(), false);
    assert.equal(
      (await fetch(url, { headers: { authorization: `Bearer ${owner}` } })).status,
      404,
    );
  });

  it('edits the profile name and password', async () => {
    const me = await register('Renamer');
    const renamed = await call('PATCH', '/me', me, { name: 'Ren' });
    assert.equal(renamed.status, 200);
    assert.equal(renamed.body.user.name, 'Ren');
    assert.equal((await call('PATCH', '/me', me, { name: ' ' })).status, 400);

    const wrong = await call('POST', '/me/password', me, {
      current: 'nope',
      next: 'newpassword1',
    });
    assert.equal(wrong.status, 400);
    const changed = await call('POST', '/me/password', me, {
      current: 'password123',
      next: 'newpassword1',
    });
    assert.equal(changed.status, 204);
    const login = await call('POST', '/auth/login', undefined, {
      email: 'renamer@example.com',
      password: 'newpassword1',
    });
    assert.equal(login.status, 200);
    assert.equal(login.body.user.name, 'Ren');
  });

  it('lets members leave and owners delete the group', async () => {
    assert.equal((await call('POST', `/groups/${groupId}/leave`, owner)).status, 409);
    assert.equal((await call('POST', `/groups/${groupId}/leave`, partner)).status, 204);
    assert.equal((await call('GET', `/groups/${groupId}`, partner)).status, 404);
    assert.equal((await call('DELETE', `/groups/${groupId}`, owner)).status, 204);
    assert.equal((await call('GET', `/groups/${groupId}`, owner)).status, 404);
  });
});
