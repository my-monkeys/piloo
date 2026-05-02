import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  parseTagToSemver,
  formatPubspecVersion,
  updatePubspecContent,
  tagFromGithubRef,
} from './set-mobile-version.mjs';

describe('parseTagToSemver', () => {
  it('extrait MAJEUR.MINEUR.PATCH d\'un tag valide', () => {
    assert.equal(parseTagToSemver('v1.2.3'), '1.2.3');
    assert.equal(parseTagToSemver('v0.0.1'), '0.0.1');
    assert.equal(parseTagToSemver('v12.34.56'), '12.34.56');
  });

  it('tolère les espaces autour du tag', () => {
    assert.equal(parseTagToSemver('  v1.2.3 \n'), '1.2.3');
  });

  it('rejette les tags sans le préfixe v', () => {
    assert.throws(() => parseTagToSemver('1.2.3'), /tag invalide/);
  });

  it('rejette les pré-releases / suffixes (le monorepo ne les utilise pas)', () => {
    assert.throws(() => parseTagToSemver('v1.2.3-rc.1'), /tag invalide/);
    assert.throws(() => parseTagToSemver('v1.2.3+build'), /tag invalide/);
  });

  it('rejette les versions partielles', () => {
    assert.throws(() => parseTagToSemver('v1.2'), /tag invalide/);
    assert.throws(() => parseTagToSemver('v1'), /tag invalide/);
  });

  it('rejette les non-strings', () => {
    assert.throws(() => parseTagToSemver(undefined), /must be a string/);
    assert.throws(() => parseTagToSemver(123), /must be a string/);
  });
});

describe('formatPubspecVersion', () => {
  it('combine semver et build number au format Flutter', () => {
    assert.equal(formatPubspecVersion('1.2.3', 42), '1.2.3+42');
    assert.equal(formatPubspecVersion('0.1.0', 1), '0.1.0+1');
  });

  it('rejette un semver malformé', () => {
    assert.throws(() => formatPubspecVersion('1.2', 1), /semver invalide/);
    assert.throws(() => formatPubspecVersion('v1.2.3', 1), /semver invalide/);
  });

  it('rejette un build number non strictement positif', () => {
    assert.throws(() => formatPubspecVersion('1.2.3', 0), /entier > 0/);
    assert.throws(() => formatPubspecVersion('1.2.3', -1), /entier > 0/);
    assert.throws(() => formatPubspecVersion('1.2.3', 1.5), /entier > 0/);
  });
});

describe('updatePubspecContent', () => {
  it('remplace la ligne version: en préservant le reste', () => {
    const before = [
      'name: piloo_mobile',
      'description: Piloo mobile app',
      'publish_to: "none"',
      'version: 0.1.0+1',
      '',
      'environment:',
      '  sdk: ">=3.4.0 <4.0.0"',
      '',
    ].join('\n');
    const after = updatePubspecContent(before, '1.2.3+42');
    assert.match(after, /^version: 1\.2\.3\+42$/m);
    assert.match(after, /^name: piloo_mobile$/m);
    assert.match(after, /^environment:$/m);
    assert.equal(after.split('\n').length, before.split('\n').length);
  });

  it('remplace seulement la ligne version: et pas une ligne similaire', () => {
    const before = [
      'name: piloo_mobile',
      'version: 0.0.1+1',
      'description: pas de version: ici, juste un mot.',
      '',
    ].join('\n');
    const after = updatePubspecContent(before, '2.0.0+10');
    assert.match(after, /^version: 2\.0\.0\+10$/m);
    assert.match(
      after,
      /^description: pas de version: ici, juste un mot\.$/m,
    );
  });

  it('throw si la ligne version: est absente', () => {
    assert.throws(
      () => updatePubspecContent('name: piloo_mobile\n', '1.0.0+1'),
      /pas de ligne `version:`/,
    );
  });
});

describe('tagFromGithubRef', () => {
  it('extrait le tag de refs/tags/<tag>', () => {
    assert.equal(tagFromGithubRef('refs/tags/v1.2.3'), 'v1.2.3');
  });

  it('retourne null pour un ref non-tag', () => {
    assert.equal(tagFromGithubRef('refs/heads/main'), null);
    assert.equal(tagFromGithubRef(''), null);
    assert.equal(tagFromGithubRef(undefined), null);
  });
});
