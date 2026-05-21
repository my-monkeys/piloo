// Provider Riverpod pour la notice ANSM scrapée (#non-ticket, suite
// remontée user sur la fiche médicament).
//
// Lazy : on n'appelle l'API que quand l'utilisateur ouvre la fiche.
// Côté serveur le résultat est caché 7 jours (cache HTTP edge Vercel),
// donc même charge réseau légère.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:piloo/shared/api/api_client_provider.dart';

class NoticeSection {
  const NoticeSection({
    required this.number,
    required this.title,
    required this.text,
  });
  final String number;
  final String title;
  final String text;
}

class BdpmNotice {
  const BdpmNotice({
    required this.cis,
    required this.sourceUrl,
    required this.sections,
  });
  final String cis;
  final String sourceUrl;
  final List<NoticeSection> sections;

  bool get isEmpty => sections.isEmpty;
}

final bdpmNoticeProvider =
    FutureProvider.family<BdpmNotice, String>((ref, cis) async {
  final client = ref.read(pilooApiClientProvider).getBdpmApi();
  final res = await client.v1BdpmCisNoticeGet(cis: cis);
  if (res.statusCode != 200 || res.data == null) {
    throw Exception('GET /v1/bdpm/$cis/notice : statut ${res.statusCode}');
  }
  final body = res.data!;
  return BdpmNotice(
    cis: body.cis,
    sourceUrl: body.sourceUrl,
    sections: body.sections
        .map((s) => NoticeSection(
              number: s.number,
              title: s.title,
              text: s.text,
            ))
        .toList(growable: false),
  );
});
