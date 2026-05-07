// Politique de confidentialité (#173).
//
// Couverture RGPD : finalités, bases légales, durées, droits, transferts.

export const metadata = {
  title: 'Politique de confidentialité — Piloo',
};

const VERSION = '2026-05-01';

export default function PrivacyPage() {
  return (
    <article>
      <p style={{ fontSize: 12, color: '#666' }}>Version : {VERSION}</p>
      <h1>Politique de confidentialité</h1>

      <p>
        Cette politique décrit comment Piloo collecte, utilise et protège les données personnelles
        des utilisateurs, conformément au règlement général sur la protection des données (RGPD) et
        à la loi Informatique et Libertés.
      </p>

      <h2>1. Responsable du traitement</h2>
      <p>
        Le responsable du traitement est l'éditeur de l'application, dont les coordonnées complètes
        figurent dans les <a href="/legal/mentions">mentions légales</a>.
      </p>

      <h2>2. Données collectées</h2>
      <ul>
        <li>
          <strong>Compte :</strong> email, prénom, nom, type de compte (particulier ou
          professionnel), mot de passe (haché, jamais stocké en clair).
        </li>
        <li>
          <strong>Officine :</strong> nom de l'officine, type, partages avec d'autres utilisateurs.
        </li>
        <li>
          <strong>Boîtes :</strong> CIP13 du médicament, lot, numéro de série, date de péremption,
          unités restantes, notes facultatives. Aucune donnée biométrique n'est collectée.
        </li>
        <li>
          <strong>Ordonnances :</strong> les pièces jointes (photos d'ordonnance) sont stockées
          chiffrées au repos. Le texte saisi (médicament, posologie, durée) est associé au compte.
        </li>
        <li>
          <strong>Techniques :</strong> identifiants de session, métadonnées de synchronisation
          (timestamps, identifiants de device). Aucun traceur publicitaire tiers n'est intégré.
        </li>
      </ul>

      <h2>3. Finalités et bases légales</h2>
      <table style={{ width: '100%', borderCollapse: 'collapse', margin: '12px 0' }}>
        <thead>
          <tr style={{ borderBottom: '1px solid #ccc', textAlign: 'left' }}>
            <th>Finalité</th>
            <th>Base légale</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Fourniture du service (compte, sync, rappels)</td>
            <td>Exécution du contrat</td>
          </tr>
          <tr>
            <td>Notifications de rappel et alertes</td>
            <td>Exécution du contrat / consentement (par canal)</td>
          </tr>
          <tr>
            <td>Sécurité, prévention de la fraude, audit</td>
            <td>Intérêt légitime</td>
          </tr>
          <tr>
            <td>Statistiques d'usage anonymisées</td>
            <td>Intérêt légitime (sans suivi individuel)</td>
          </tr>
        </tbody>
      </table>

      <h2>4. Données de santé</h2>
      <p>
        Les données saisies dans Piloo (médicaments, dates de prise) constituent des données de
        santé au sens de l'article 9 du RGPD. Elles sont traitées sur la base du consentement
        explicite de l'utilisateur, recueilli à l'inscription, et conservées sur un hébergement
        sécurisé. Une certification HDS (Hébergeur de Données de Santé) sera mise en place avant la
        sortie commerciale du produit.
      </p>

      <h2>5. Destinataires</h2>
      <ul>
        <li>L'utilisateur lui-même.</li>
        <li>Les personnes auxquelles il a explicitement partagé son officine.</li>
        <li>
          Les sous-traitants techniques (hébergeur, fournisseur de notifications) dans la stricte
          mesure nécessaire au service. Aucune donnée n'est cédée ou vendue à des tiers à des fins
          commerciales.
        </li>
      </ul>

      <h2>6. Durées de conservation</h2>
      <ul>
        <li>Compte actif : tant que l'utilisateur l'utilise.</li>
        <li>Compte inactif : suppression automatique après 24 mois sans connexion.</li>
        <li>Demande de suppression : effective sous 30 jours (délai de rétractation 7 jours).</li>
        <li>
          Logs techniques anonymisés : 13 mois (conformité aux recommandations CNIL pour les logs de
          sécurité).
        </li>
      </ul>

      <h2>7. Droits de l'utilisateur</h2>
      <p>Conformément au RGPD, vous disposez des droits suivants :</p>
      <ul>
        <li>Accès à vos données et copie</li>
        <li>Rectification</li>
        <li>Effacement</li>
        <li>Portabilité (export structuré JSON)</li>
        <li>Opposition au traitement</li>
        <li>Limitation du traitement</li>
      </ul>
      <p>
        Pour exercer ces droits : <a href="mailto:dpo@piloo.fr">dpo@piloo.fr</a>. En cas de litige
        non résolu, vous pouvez introduire une réclamation auprès de la CNIL{' '}
        <a href="https://www.cnil.fr">cnil.fr</a>.
      </p>

      <h2>8. Sécurité</h2>
      <ul>
        <li>Chiffrement TLS systématique en transit.</li>
        <li>Mots de passe hachés avec un algorithme à coût adaptatif.</li>
        <li>Authentification à deux facteurs disponible (TOTP).</li>
        <li>Audit annuel des accès, journaux anonymisés.</li>
        <li>
          Aucun nom de médicament, CIP, ou identifiant patient n'apparaît en clair dans les journaux
          serveur.
        </li>
      </ul>

      <h2>9. Transferts hors UE</h2>
      <p>
        Les données sont hébergées au sein de l'Union européenne. Aucun transfert hors UE n'est
        effectué dans le cadre du fonctionnement nominal de l'application.
      </p>

      <h2>10. Cookies</h2>
      <p>
        Piloo utilise uniquement des cookies strictement nécessaires (session, préférence de thème).
        Aucun cookie tiers de mesure d'audience publicitaire n'est déposé.
      </p>

      <p style={{ marginTop: 32 }}>
        <a href="/legal/cgu">CGU</a> · <a href="/legal/mentions">Mentions légales</a>
      </p>
    </article>
  );
}
