import type { ErrorRequestHandler, RequestHandler } from 'express';
import { ZodError } from 'zod';

export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export const notFound = (what: string) => new HttpError(404, `${what} not found`);
export const forbidden = (message = 'Not allowed') => new HttpError(403, message);

export const unknownRoute: RequestHandler = (_req, _res, next) =>
  next(new HttpError(404, 'Route not found'));

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof ZodError) {
    res.status(400).json({
      error: 'Invalid request',
      issues: err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
    });
    return;
  }
  if (err instanceof HttpError) {
    res.status(err.status).json({ error: err.message });
    return;
  }
  // Malformed JSON body from express.json().
  if (err?.type === 'entity.parse.failed') {
    res.status(400).json({ error: 'Body must be valid JSON' });
    return;
  }
  console.error(err);
  res.status(500).json({ error: 'Something went wrong' });
};
