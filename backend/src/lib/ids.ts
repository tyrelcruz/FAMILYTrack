import { randomInt, randomUUID } from 'node:crypto';

export const newId = () => randomUUID();

// No 0/O or 1/I so codes are easy to read out loud.
const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function newInviteCode(length = 6): string {
  let code = '';
  for (let i = 0; i < length; i++) {
    code += INVITE_ALPHABET[randomInt(INVITE_ALPHABET.length)];
  }
  return code;
}

/** Avatar colors (ARGB ints), the same palette as the app's FamilyMember. */
export const MEMBER_PALETTE = [
  0xff2563eb, 0xff7356f6, 0xff16a34a, 0xfff59e0b, 0xfff04b57, 0xff00acc1,
  0xffd81b60,
];

export const paletteColor = (index: number) =>
  MEMBER_PALETTE[index % MEMBER_PALETTE.length]!;
