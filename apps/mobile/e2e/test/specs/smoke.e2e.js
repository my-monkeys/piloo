// Smoke test : l'app se lance et affiche une UI.
describe('piloo (mobile) — smoke', () => {
  it('lance l’app et trouve une UI non vide', async () => {
    await driver.pause(3000); // laisse l'app arriver au premier plan

    const src = await driver.getPageSource();
    if (!src || src.length < 50) {
      throw new Error('Page source vide — l’app ne semble pas lancée.');
    }

    const interactifs = await $$('//XCUIElementTypeButton | //XCUIElementTypeStaticText');
    console.log('Éléments UI détectés :', interactifs.length);
    if (interactifs.length === 0) {
      throw new Error('Aucun élément UI détecté.');
    }
  });
});
