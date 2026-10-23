/** Database rows and their JSON shapes (camelCase, matching the app). */

export interface UserRow {
  id: string;
  name: string;
  email: string;
  password_hash: string;
  created_at: number;
}

export interface GroupRow {
  id: string;
  name: string;
  invite_code: string;
  owner_id: string;
  created_at: number;
  updated_at: number;
}

export interface MemberRow {
  id: string;
  group_id: string;
  user_id: string | null;
  name: string;
  color: number;
  role: 'owner' | 'member';
  created_at: number;
  updated_at: number;
  deleted_at: number | null;
}

export interface TransactionRow {
  id: string;
  group_id: string;
  member_id: string | null;
  title: string;
  amount: number;
  type: 'income' | 'expense';
  category: string;
  date: number;
  note: string;
  plan_id: string | null;
  payment_method: PaymentMethod | null;
  has_photo: number;
  created_by: string;
  created_at: number;
  updated_at: number;
  deleted_at: number | null;
}

export const PAYMENT_METHODS = ['cash', 'ewallet', 'card', 'bank'] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

export interface PlanRow {
  id: string;
  group_id: string;
  name: string;
  kind: 'trip' | 'event' | 'monthly' | 'custom';
  start_date: number;
  end_date: number;
  /** JSON: { cash: 5000, ewallet: 2000 } */
  funds: string;
  /** JSON: { <memberId>: 2500 } */
  shares: string;
  split: 'equal' | 'custom';
  destination: string;
  description: string;
  has_cover: number;
  created_by: string;
  created_at: number;
  updated_at: number;
  deleted_at: number | null;
}

export interface TransferRow {
  id: string;
  group_id: string;
  kind: 'wallet' | 'people';
  amount: number;
  from_method: PaymentMethod | null;
  to_method: PaymentMethod | null;
  from_member_id: string | null;
  to_member_id: string | null;
  plan_id: string | null;
  note: string;
  date: number;
  created_by: string;
  created_at: number;
  updated_at: number;
  deleted_at: number | null;
}

export interface ActivityRow {
  id: string;
  group_id: string;
  actor_user_id: string | null;
  actor_name: string;
  kind: string;
  /** JSON details, e.g. { title, amount } for an expense. */
  data: string;
  created_at: number;
}

export interface BudgetRow {
  id: string;
  group_id: string;
  category: string;
  amount: number;
  updated_at: number;
  deleted_at: number | null;
}

export const userJson = (u: UserRow) => ({
  id: u.id,
  name: u.name,
  email: u.email,
  createdAt: u.created_at,
});

export const groupJson = (g: GroupRow) => ({
  id: g.id,
  name: g.name,
  inviteCode: g.invite_code,
  ownerId: g.owner_id,
  createdAt: g.created_at,
  updatedAt: g.updated_at,
});

export const memberJson = (m: MemberRow) => ({
  id: m.id,
  userId: m.user_id,
  name: m.name,
  color: m.color,
  role: m.role,
  isOwner: m.role === 'owner',
  updatedAt: m.updated_at,
  deleted: m.deleted_at !== null,
});

export const transactionJson = (t: TransactionRow) => ({
  id: t.id,
  memberId: t.member_id,
  title: t.title,
  amount: t.amount,
  type: t.type,
  categoryId: t.category,
  date: t.date,
  note: t.note,
  planId: t.plan_id,
  paymentMethod: t.payment_method,
  hasPhoto: t.has_photo === 1,
  createdBy: t.created_by,
  updatedAt: t.updated_at,
  deleted: t.deleted_at !== null,
});

export const planJson = (p: PlanRow) => ({
  id: p.id,
  name: p.name,
  kind: p.kind,
  startDate: p.start_date,
  endDate: p.end_date,
  funds: JSON.parse(p.funds) as Record<string, number>,
  shares: JSON.parse(p.shares) as Record<string, number>,
  split: p.split,
  destination: p.destination,
  description: p.description,
  hasCover: p.has_cover === 1,
  createdBy: p.created_by,
  updatedAt: p.updated_at,
  deleted: p.deleted_at !== null,
});

export const transferJson = (t: TransferRow) => ({
  id: t.id,
  kind: t.kind,
  amount: t.amount,
  fromMethod: t.from_method,
  toMethod: t.to_method,
  fromMemberId: t.from_member_id,
  toMemberId: t.to_member_id,
  planId: t.plan_id,
  note: t.note,
  date: t.date,
  createdBy: t.created_by,
  updatedAt: t.updated_at,
  deleted: t.deleted_at !== null,
});

export const activityJson = (a: ActivityRow) => ({
  id: a.id,
  actorUserId: a.actor_user_id,
  actorName: a.actor_name,
  kind: a.kind,
  data: JSON.parse(a.data) as Record<string, unknown>,
  createdAt: a.created_at,
});

export const budgetJson = (b: BudgetRow) => ({
  id: b.id,
  categoryId: b.category,
  limit: b.amount,
  updatedAt: b.updated_at,
  deleted: b.deleted_at !== null,
});
