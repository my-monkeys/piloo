// Format d'erreur unifié pour les API Routes (cf. docs/api-contract.md §"Format des erreurs").
// Toute erreur de validation Zod en amont d'un handler doit passer par `zodErrorResponse`
// pour garantir le même format côté clients (web + Dart généré).
import type { ZodError } from 'zod';

export type ApiErrorCode =
  | 'validation_error'
  | 'unauthorized'
  | 'forbidden'
  | 'not_found'
  | 'conflict'
  | 'business_rule_error'
  | 'rate_limited'
  | 'internal_error';

export interface ApiErrorBody {
  error: {
    code: ApiErrorCode;
    message: string;
    details?: Record<string, unknown>;
  };
}

const HTTP_STATUS: Record<ApiErrorCode, number> = {
  validation_error: 400,
  unauthorized: 401,
  forbidden: 403,
  not_found: 404,
  conflict: 409,
  business_rule_error: 422,
  rate_limited: 429,
  internal_error: 500,
};

export function apiErrorResponse(
  code: ApiErrorCode,
  message: string,
  details?: Record<string, unknown>,
): Response {
  const body: ApiErrorBody = {
    error: details ? { code, message, details } : { code, message },
  };
  return Response.json(body, { status: HTTP_STATUS[code] });
}

export function zodErrorResponse(error: ZodError): Response {
  const issues = error.issues.map((issue) => ({
    path: issue.path.join('.'),
    message: issue.message,
    code: issue.code,
  }));
  const first = issues[0];
  const message = first ? `${first.path || '(root)'}: ${first.message}` : 'Validation failed';
  return apiErrorResponse('validation_error', message, { issues });
}
