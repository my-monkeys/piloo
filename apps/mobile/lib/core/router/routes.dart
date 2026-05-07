// Source unique de vérité des paths du router (#45). À chaque écran M1
// (cf. docs/ui-ux-guidelines.md §"Écrans mobile") correspond une `RoutePath`
// : un nom de route stable et une fonction de construction de path
// type-safe. Évite les strings magiques disséminés dans le code et les
// erreurs de typo sur les paramètres de chemin.
//
// Tant que `go_router_builder` n'est pas câblé (déférré : il pèse un
// `build_runner` non encore présent), on garde des helpers manuels —
// ils fournissent l'essentiel du bénéfice typage.

class RouteName {
  RouteName._();

  // Onboarding & auth
  static const splash = 'splash';
  static const welcome = 'welcome';
  static const accountType = 'account-type';
  static const signIn = 'sign-in';
  static const signUp = 'sign-up';
  static const verifyEmail = 'verify-email';
  static const forgotPassword = 'forgot-password';
  static const resetPassword = 'reset-password';
  static const legal = 'legal';
  static const permissions = 'permissions';

  // Coquille principale (ShellRoute)
  static const today = 'today';
  static const officine = 'officine';
  static const more = 'more';

  // Actions globales
  static const scan = 'scan';
  static const alertes = 'alertes';

  // Boîtes
  static const boiteAdd = 'boite-add';
  static const boiteDetail = 'boite-detail';
  static const medicamentInfo = 'medicament-info';

  // Ordonnances
  static const ordonnances = 'ordonnances';
  static const ordonnanceCreate = 'ordonnance-create';
  static const ordonnanceDetail = 'ordonnance-detail';
  static const ordonnanceOcr = 'ordonnance-ocr';

  // Officines & partages
  static const officinesList = 'officines-list';
  static const officineSettings = 'officine-settings';
  static const partages = 'partages';
  static const invite = 'invite';
  static const invitationAccept = 'invitation-accept';

  // Settings
  static const settings = 'settings';
  static const settingsProfile = 'settings-profile';
  static const settingsNotifications = 'settings-notifications';
  static const settingsHoraires = 'settings-horaires';
  static const settingsSecurity = 'settings-security';

  // Vue pro
  static const proDashboard = 'pro-dashboard';

  // Dev only — accessible via 5 taps sur le logo du splash. Reste
  // présent en release mais sans entrée d'UI visible.
  static const dev = 'dev';
}

/// Helpers typés pour construire les paths. Préférer ces fonctions à
/// `context.goNamed(...)` pour les routes paramétrées : elles imposent
/// les arguments et restent stables si le path change.
class RoutePath {
  RoutePath._();

  // Onboarding & auth (chemins absolus)
  static const splash = '/';
  static const welcome = '/welcome';
  static const accountType = '/account-type';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const legal = '/legal';
  static const permissions = '/permissions';

  // Tab bar (sous une ShellRoute)
  static const today = '/today';
  static const officine = '/officine';
  static const more = '/more';

  // Actions globales
  static const scan = '/scan';
  static const alertes = '/alertes';

  // Boîtes — paramètre id requis
  static const boiteAdd = '/boites/add';
  static String boiteDetail(String boiteId) => '/boites/$boiteId';
  static String medicamentInfo(String cip13) => '/medicaments/$cip13';

  // Ordonnances
  static const ordonnances = '/ordonnances';
  static const ordonnanceCreate = '/ordonnances/create';
  static const ordonnanceOcr = '/ordonnances/ocr';
  static String ordonnanceDetail(String ordonnanceId) =>
      '/ordonnances/$ordonnanceId';

  // Officines & partages
  static const officinesList = '/officines';
  static String officineSettings(String officineId) =>
      '/officines/$officineId/settings';
  static String partages(String officineId) =>
      '/officines/$officineId/partages';
  static String invite(String officineId) =>
      '/officines/$officineId/invite';
  static String invitationAccept(String token) => '/invitations/$token';

  // Settings
  static const settings = '/settings';
  static const settingsProfile = '/settings/profile';
  static const settingsNotifications = '/settings/notifications';
  static const settingsHoraires = '/settings/horaires';
  static const settingsSecurity = '/settings/security';

  // Vue pro
  static const proDashboard = '/pro';

  // Dev only.
  static const dev = '/_dev';
}
