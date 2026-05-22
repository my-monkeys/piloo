// Config lint-staged pour le monorepo (lue par husky pre-commit, cf.
// `.husky/pre-commit`).
//
// Les fonctions qui retournent une string (au lieu de la string directe)
// indiquent à lint-staged "ignore la liste des fichiers, lance la
// commande UNE seule fois" — utile quand le linter (flutter analyze)
// préfère scanner tout le module plutôt qu'un fichier à la fois.

module.exports = {
  '*.{ts,tsx,mts,cts,js,mjs,cjs,jsx}': ['eslint --fix', 'prettier --write'],
  '*.{json,md,yml,yaml,css}': ['prettier --write'],

  // Côté Flutter : un seul `flutter analyze --no-fatal-infos` couvrant
  // tout apps/mobile, quel que soit le fichier .dart touché. Coûte
  // ~5-10s mais évite les builds Codemagic qui fail à l'analyse
  // statique (cf. v0.1.31 et v0.1.33 cassés sur warnings unused
  // `_sending` / `_doseSingular`, 2026-05-22).
  //
  // --no-fatal-infos ignore les hints (deprecated_member_use, etc.) car
  // beaucoup viennent de tests legacy et bloqueraient injustement les
  // commits. Les errors + warnings restent fatals — c'est ce qu'on veut.
  'apps/mobile/**/*.dart': () => 'bash -c "cd apps/mobile && flutter analyze --no-fatal-infos"',
};
