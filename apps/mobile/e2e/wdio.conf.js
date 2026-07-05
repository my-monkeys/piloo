// WebdriverIO + Appium (XCUITest) — piloo (mobile) sur iPhone réel "Crookie".
//
// Prérequis runtime (3 terminaux) :
//   1) (iOS 18+) tunnel : npm run tunnel      # = sudo appium driver run xcuitest tunnel-creation (laisser tourner)
//   2) serveur Appium   : npm run appium      # port 4723
//   3) tests            : npm test
//
// Au 1er lancement, Appium build + signe le WebDriverAgent (team ci-dessous).
// L'iPhone doit être déverrouillé, connecté et "approuvé". Si Xcode demande
// d'approuver le profil dev : Réglages > Général > VPN & gestion d'appareils.

const APP_BUNDLE_ID = process.env.APP_BUNDLE_ID || 'fr.mymonkey.piloo';

exports.config = {
  runner: 'local',
  hostname: process.env.APPIUM_HOST || '127.0.0.1',
  port: Number(process.env.APPIUM_PORT || 4723),
  path: '/',

  // 1er build du WebDriverAgent (signature + install device) = plusieurs minutes :
  // on laisse le client attendre la création de session.
  connectionRetryTimeout: 600000,
  connectionRetryCount: 0,

  specs: ['./test/specs/**/*.e2e.js'],
  maxInstances: 1,

  capabilities: [
    {
      platformName: 'iOS',
      'appium:automationName': 'XCUITest',
      'appium:udid': process.env.IOS_UDID || '00008150-001409EA0A78401C',
      'appium:deviceName': 'Crookie',

      // S'attache à l'app DÉJÀ installée sur l'appareil.
      // Pour (ré)installer un build à la place, commente cette ligne et décommente 'appium:app'.
      'appium:bundleId': APP_BUNDLE_ID,
      // 'appium:app': '/chemin/vers/Runner.ipa',

      // Signature du WebDriverAgent pour appareil réel :
      'appium:xcodeOrgId': process.env.XCODE_ORG_ID || '82CD4B7L8X',
      'appium:xcodeSigningId': 'Apple Development',
      'appium:updatedWDABundleId':
        process.env.WDA_BUNDLE_ID || 'com.scalabgames.WebDriverAgentRunner',

      'appium:wdaLaunchTimeout': 300000,
      'appium:wdaConnectionTimeout': 300000,
      'appium:newCommandTimeout': 120,
      'appium:showXcodeLog': true,
    },
  ],

  logLevel: 'info',
  framework: 'mocha',
  reporters: ['spec'],
  mochaOpts: { ui: 'bdd', timeout: 240000 },
};
