// Génère les visuels de la fiche Play Store (#406).
//
//   node docs/playstore/generate.mjs
//
// Entrées  : docs/playstore/raw/*.png (captures réelles de l'émulateur)
//            docs/playstore/slides.json (textes)
// Sorties  : docs/playstore/out/screenshot-N.png (1080x1920, 9:16)
//            docs/playstore/out/feature-graphic.png (1024x500, obligatoire)
//
// Rejouable : re-capturer l'émulateur, relancer, les visuels sont à jour.
// Playwright vient de apps/web (déjà une devDependency pour les tests E2E).
/* global document -- les callbacks page.evaluate() s'exécutent dans le navigateur. */
import { readFile, mkdir, readdir } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));

// La résolution ESM part du dossier de CE fichier, où il n'y a pas de
// node_modules : on résout depuis le workspace web, qui a déjà
// @playwright/test pour ses tests E2E.
const requireFromWeb = createRequire(join(HERE, '..', '..', 'apps', 'web', 'package.json'));
const { chromium } = requireFromWeb('@playwright/test');
const OUT = join(HERE, 'out');

const SCREEN = { width: 1080, height: 1920 };
const FEATURE = { width: 1024, height: 500 };

async function main() {
  const slides = JSON.parse(await readFile(join(HERE, 'slides.json'), 'utf8'));
  const available = new Set(await readdir(join(HERE, 'raw')));
  await mkdir(OUT, { recursive: true });

  const browser = await chromium.launch();
  try {
    await renderSlides(browser, slides, available);
    await renderFeatureGraphic(browser);
  } finally {
    await browser.close();
  }
}

async function renderSlides(browser, slides, available) {
  const page = await browser.newPage({ viewport: SCREEN, deviceScaleFactor: 1 });
  await page.goto(pathToFileURL(join(HERE, 'template.html')).href);

  let index = 0;
  for (const slide of slides) {
    if (!available.has(slide.file)) {
      console.warn(`⚠ capture manquante, slide ignorée : ${slide.file}`);
      continue;
    }
    index += 1;
    // L'image est injectée en data URI : file:// dans un <img> est bloqué
    // par la même origine selon la plateforme.
    const png = await readFile(join(HERE, 'raw', slide.file));
    await page.evaluate(
      ({ eyebrow, title, sub, dataUri }) => {
        document.getElementById('eyebrow').textContent = eyebrow;
        document.getElementById('title').innerHTML = title;
        document.getElementById('sub').textContent = sub;
        document.getElementById('shot').src = dataUri;
      },
      { ...slide, dataUri: `data:image/png;base64,${png.toString('base64')}` },
    );
    await page.waitForFunction(() => {
      const img = document.getElementById('shot');
      return img.complete && img.naturalWidth > 0;
    });
    await page.evaluate(() => document.fonts.ready);
    const out = join(OUT, `screenshot-${index}.png`);
    await page.screenshot({ path: out });
    console.info(`✓ ${out}`);
  }
  await page.close();
}

async function renderFeatureGraphic(browser) {
  // Bandeau d'en-tête de la fiche : logo + nom + accroche. Pas de texte
  // près des bords (Play recadre le bandeau selon les surfaces).
  const html = `<!doctype html><html lang="fr"><head><meta charset="utf-8">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500&family=Manrope:wght@600&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0}
body{width:1024px;height:500px;overflow:hidden;position:relative;background:#4a6b64;
  font-family:'Manrope',system-ui,sans-serif;display:grid;place-items:center}
.blob{position:absolute;border-radius:50%;filter:blur(80px)}
.b1{width:520px;height:520px;top:-200px;left:-120px;background:#6d8b84;opacity:.55}
.b2{width:420px;height:420px;bottom:-200px;right:-80px;background:#a8472e;opacity:.3}
.wrap{position:relative;z-index:1;text-align:center;padding:0 90px}
.name{font-family:'Fraunces',Georgia,serif;font-size:92px;font-weight:500;color:#fff;letter-spacing:-.02em;line-height:1}
.tag{margin-top:22px;font-size:31px;font-weight:600;color:rgba(255,255,255,.85)}
</style></head><body>
<span class="blob b1"></span><span class="blob b2"></span>
<div class="wrap">
  <div class="name">Piloo</div>
  <div class="tag">Ton carnet de médicaments, au calme.</div>
</div>
</body></html>`;
  const page = await browser.newPage({ viewport: FEATURE, deviceScaleFactor: 1 });
  await page.setContent(html, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  const out = join(OUT, 'feature-graphic.png');
  await page.screenshot({ path: out });
  console.info(`✓ ${out}`);
  await page.close();
}

await main();
