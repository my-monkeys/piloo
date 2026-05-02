// Conventional Commits — voir CLAUDE.md §"Conventions de code".
// Types acceptés : feat, fix, refactor, docs, chore, test, ci, style, perf, build, revert.
/** @type {import('@commitlint/types').UserConfig} */
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'subject-case': [0],
  },
};
