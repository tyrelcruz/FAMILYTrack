import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

/** Where uploaded image files live; swap for S3/R2 without touching routes. */
export interface BlobStore {
  put(key: string, bytes: Buffer): void;
  /** Absolute path of the stored file, or null when there isn't one. */
  path(key: string): string | null;
  remove(key: string): void;
}

const SAFE_KEY = /^[\w-]+(\/[\w-]+)*$/;

/** Files under [dir], one `<key>.jpg` each. Keys look like "<groupId>/<id>". */
export function diskBlobStore(dir: string): BlobStore {
  const file = (key: string) => {
    if (!SAFE_KEY.test(key)) throw new Error(`Bad blob key: ${key}`);
    return join(dir, `${key}.jpg`);
  };
  return {
    put(key, bytes) {
      const f = file(key);
      mkdirSync(dirname(f), { recursive: true });
      writeFileSync(f, bytes);
    },
    path(key) {
      const f = file(key);
      return existsSync(f) ? f : null;
    },
    remove(key) {
      rmSync(file(key), { force: true });
    },
  };
}

/** JPEG, PNG, WebP or HEIC, judged from the bytes, never the declared type. */
export function looksLikeImage(bytes: Buffer): boolean {
  const head = bytes.subarray(0, 12);
  return (
    (head[0] === 0xff && head[1] === 0xd8) ||
    head.subarray(1, 4).toString() === 'PNG' ||
    (head.subarray(0, 4).toString() === 'RIFF' &&
      head.subarray(8, 12).toString() === 'WEBP') ||
    head.subarray(4, 8).toString() === 'ftyp'
  );
}
