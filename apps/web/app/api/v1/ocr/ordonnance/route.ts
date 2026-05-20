// POST /api/v1/ocr/ordonnance (#152).
//
// Reçoit une image base64 et renvoie le contenu structuré extrait
// par Gemini vision. Pas de persistance — l'utilisateur valide ligne
// par ligne dans l'app puis appelle POST /v1/officines/{id}/ordonnances
// pour créer.
import { OcrOrdonnanceInputSchema } from '@piloo/api-contract';

import { requireAuth } from '@/lib/auth/guards';
import { ocrOrdonnance } from '@/lib/ocr/ocr-ordonnance';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';
// Vision LLM peut prendre 10-20s sur une photo HD. On garde 30s de marge.
export const maxDuration = 30;

export async function POST(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsed = OcrOrdonnanceInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  try {
    const result = await ocrOrdonnance({
      imageBase64: parsed.data.image_base64,
      mimeType: parsed.data.mime_type,
    });
    if (result.prescriptions.length === 0) {
      // Aucune ligne extraite : l'image n'est probablement pas une
      // ordonnance. On laisse l'utilisateur retenter avec une autre
      // photo plutôt que de stocker un résultat vide. business_rule_error
      // mappe sur 422 dans le mapping HTTP (cf. lib/server/errors).
      log.warn('ocr.ordonnance.empty', { userId: auth.user.id });
      return apiErrorResponse(
        'business_rule_error',
        "Aucune prescription extractible — la photo est peut-être floue ou ne contient pas d'ordonnance.",
      );
    }
    return Response.json(result, { status: 200 });
  } catch (e) {
    log.error('ocr.ordonnance.error', {
      userId: auth.user.id,
      message: e instanceof Error ? e.message : String(e),
    });
    return apiErrorResponse('internal_error', "Impossible d'extraire le contenu de l'image.");
  }
}
