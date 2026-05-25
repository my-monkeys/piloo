import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'features/auth/data/session.dart';
import 'features/auth/presentation/session_provider.dart';
import 'features/onboarding/presentation/onboarding_overlay.dart';
import 'shared/notifications/fcm_service.dart';
import 'shared/sync/sync_providers.dart';

class PilooApp extends ConsumerStatefulWidget {
  const PilooApp({super.key});

  @override
  ConsumerState<PilooApp> createState() => _PilooAppState();
}

class _PilooAppState extends ConsumerState<PilooApp> {
  // Router lu depuis routerProvider (override dans main.dart). Instancié
  // au boot pour pouvoir être consommé aussi par l'overlay onboarding
  // (#351) hors du Navigator. Le dispose se fait via le ProviderScope.
  StreamSubscription<String>? _fcmRefreshSub;
  bool _fcmRegistered = false;

  @override
  void dispose() {
    _fcmRefreshSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Boot du SyncWorker (#18) : la lecture du FutureProvider
    // l'instancie et appelle start() (subscription connectivity_plus).
    // On ignore l'AsyncValue retournée — l'erreur ne doit pas bloquer
    // l'app (la sync est best-effort).
    ref.watch(syncWorkerProvider);

    // Register FCM token quand l'user est connecté (#122).
    // Refait à chaque transition vers une session valide. Le serveur
    // dédup par (user_id, token).
    ref.listen<AsyncValue<Session?>>(sessionProvider, (_, next) {
      final session = next.value;
      if (session != null && !_fcmRegistered) {
        _fcmRegistered = true;
        // ignore: discarded_futures
        _registerFcm();
      } else if (session == null) {
        _fcmRegistered = false;
      }
    });

    return MaterialApp.router(
      title: 'Piloo',
      theme: pilooLightTheme(),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      // Stack global pour superposer l'overlay du tour guidé (#351).
      // OnboardingOverlay = SizedBox.shrink si demoMode = false.
      // L'overlay retourne lui-même un Positioned, donc direct child
      // du Stack (sans Positioned.fill autour qui casserait le layout).
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const OnboardingOverlay(),
          ],
        );
      },
    );
  }

  Future<void> _registerFcm() async {
    final fcm = ref.read(fcmServiceProvider);
    final token = await fcm.getToken();
    if (token == null) return;
    try {
      await registerFcmToken(ref, token: token, appVersion: '0.1.x');
    } catch (_) {
      // Best-effort : si l'enregistrement échoue (offline, 401), on
      // ré-essaiera au prochain refresh ou re-login.
    }
    _fcmRefreshSub ??= fcm.onTokenRefresh.listen((newToken) {
      // ignore: discarded_futures
      registerFcmToken(ref, token: newToken, appVersion: '0.1.x');
    });
  }
}
