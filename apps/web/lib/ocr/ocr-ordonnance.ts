// OCR ordonnance via Gemini vision (#152 / parent #13).
//
// Prend une image (base64 ou Buffer) d'une ordonnance papier ou
// dématérialisée et retourne une structure JSON :
//   {
//     prescripteur: "Dr Sophie Laurent",
//     specialite: "Cardiologue",
//     date_prescription: "2026-05-20",
//     prescriptions: [
//       { nom_texte, posologie: { unitesParPrise, unite, frequence },
//         duree_jours, indication, notes }
//     ]
//   }
//
// L'utilisateur DOIT valider chaque ligne avant création (cf. AC #152).
// Le serveur ne crée RIEN — il extrait, le client appelle ensuite
// POST /v1/officines/{id}/ordonnances pour persister.
//
// Garanties produit :
//   - Aucune création serveur, juste un parseur vision pur.
//   - Le résumé d'usage / posologie reste interprété par le médecin —
//     on extrait LITTÉRALEMENT ce qui est écrit, sans inventer.
//   - Coût : ~$0.001/photo avec gemini-2.5-flash. Pas de cache image
//     côté serveur (RGPD : photo possiblement nominative).
import { GoogleGenAI, Type } from '@google/genai';

const MODEL = 'gemini-2.5-flash';

const SYSTEM_PROMPT = `Tu extrais le contenu d'une ordonnance médicale française pour
pré-remplir un formulaire dans l'app Piloo. Tu ne crées rien : tu
recopies LITTÉRALEMENT ce qui est écrit. Si un champ n'est pas
lisible ou absent, mets null.

Règles strictes :
- Conserve les libellés exacts du médicament (nom commercial ou DCI tel
  qu'écrit, avec dosage).
- Posologie : extraire unités par prise, unité (comprimé / gélule /
  sachet / ml…), fréquence (matin, soir, 3 fois par jour…).
- Date : format YYYY-MM-DD. Si seul "mai 2026", prendre le 1er.
- Prescripteur : "Dr Prénom Nom" si présent.
- N'invente jamais de durée ou d'indication si pas explicite.
- Tu réponds UNIQUEMENT en JSON valide selon le schéma fourni.`;

/// Schéma de sortie strict (Google GenAI structured output).
const RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    prescripteur: {
      type: Type.STRING,
      nullable: true,
      description: '"Dr Prénom Nom" tel qu\'écrit sur l\'ordonnance, ou null si absent',
    },
    specialite: {
      type: Type.STRING,
      nullable: true,
      description: 'Spécialité du prescripteur (cardiologue, médecin traitant, ORL…)',
    },
    date_prescription: {
      type: Type.STRING,
      nullable: true,
      description: 'Date au format YYYY-MM-DD, ou null si illisible',
    },
    notes: {
      type: Type.STRING,
      nullable: true,
      description: "Notes générales de l'ordonnance (mentions hors prescriptions)",
    },
    prescriptions: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          nom_texte: {
            type: Type.STRING,
            description: "Nom du médicament tel qu'écrit, avec dosage si présent",
          },
          unites_par_prise: { type: Type.NUMBER, nullable: true },
          unite: {
            type: Type.STRING,
            nullable: true,
            description: 'Comprimé, gélule, sachet, ml, goutte…',
          },
          frequence: {
            type: Type.STRING,
            nullable: true,
            description: 'Fréquence telle qu\'écrite : "matin", "3 fois par jour", "si douleur"',
          },
          duree_jours: { type: Type.NUMBER, nullable: true },
          indication: {
            type: Type.STRING,
            nullable: true,
            description: 'Indication explicite ("si douleur", "pour la fièvre")',
          },
        },
        required: ['nom_texte'],
        propertyOrdering: [
          'nom_texte',
          'unites_par_prise',
          'unite',
          'frequence',
          'duree_jours',
          'indication',
        ],
      },
    },
  },
  required: ['prescriptions'],
  propertyOrdering: ['prescripteur', 'specialite', 'date_prescription', 'notes', 'prescriptions'],
};

export interface OcrPrescription {
  nom_texte: string;
  unites_par_prise: number | null;
  unite: string | null;
  frequence: string | null;
  duree_jours: number | null;
  indication: string | null;
}

export interface OcrOrdonnanceResult {
  prescripteur: string | null;
  specialite: string | null;
  date_prescription: string | null;
  notes: string | null;
  prescriptions: OcrPrescription[];
}

export interface OcrOrdonnanceInput {
  /// Image en base64 (sans le préfixe data:…;base64,)
  imageBase64: string;
  /// MIME type (image/jpeg, image/png, image/heic). HEIC supporté par
  /// Gemini directement.
  mimeType: string;
  /// Optionnel : clé API (par défaut GEMINI_API_KEY env).
  apiKey?: string;
}

export async function ocrOrdonnance(input: OcrOrdonnanceInput): Promise<OcrOrdonnanceResult> {
  const apiKey = input.apiKey ?? process.env['GEMINI_API_KEY'] ?? process.env['GOOGLE_API_KEY'];
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY (ou GOOGLE_API_KEY) non défini');
  }

  const client = new GoogleGenAI({ apiKey });
  const res = await client.models.generateContent({
    model: MODEL,
    contents: [
      {
        role: 'user',
        parts: [
          { text: 'Extrait le contenu de cette ordonnance :' },
          { inlineData: { data: input.imageBase64, mimeType: input.mimeType } },
        ],
      },
    ],
    config: {
      systemInstruction: SYSTEM_PROMPT,
      responseMimeType: 'application/json',
      responseSchema: RESPONSE_SCHEMA,
      // Pas de thinking — on veut juste l'extraction structurée.
      thinkingConfig: { thinkingBudget: 0 },
      temperature: 0,
    },
  });

  const raw = (res.text ?? '').trim();
  if (raw.length === 0) {
    throw new Error('Réponse Gemini vide');
  }
  try {
    return JSON.parse(raw) as OcrOrdonnanceResult;
  } catch (e) {
    throw new Error(`JSON invalide : ${e instanceof Error ? e.message : String(e)}`, {
      cause: e,
    });
  }
}
