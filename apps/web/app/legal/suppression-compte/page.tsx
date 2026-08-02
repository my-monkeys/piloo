// Page publique de suppression de compte (#400).
//
// Exigée par Google Play (Data safety) pour toute app permettant la
// création de compte : l'URL doit être accessible SANS être connecté et
// décrire la suppression in-app + une voie de recours pour quelqu'un qui
// n'a plus l'application. Apple s'en sert aussi comme référence externe.

export const metadata = {
  title: 'Supprimer mon compte — Piloo',
  description: 'Comment supprimer définitivement ton compte Piloo et toutes les données associées.',
};

const VERSION = '2026-08-02';

export default function SuppressionComptePage() {
  return (
    <article>
      <p className="legal-version">Version : {VERSION}</p>
      <h1>Supprimer mon compte</h1>

      <p>
        Tu peux supprimer ton compte Piloo et toutes les données associées à tout moment, sans avoir
        à nous contacter. La suppression est définitive.
      </p>

      <h2>Depuis l&apos;application</h2>
      <p>C&apos;est la voie la plus rapide, sur iPhone comme sur Android :</p>
      <ul>
        <li>
          Ouvre l&apos;onglet <strong>Plus</strong> (en bas à droite).
        </li>
        <li>
          Touche <strong>Supprimer mon compte</strong>, en bas de l&apos;écran. Le lien est aussi
          accessible depuis <strong>Plus › ta fiche profil</strong>.
        </li>
        <li>
          Coche la case de confirmation, puis touche <strong>Supprimer définitivement</strong>.
        </li>
      </ul>

      <h2>Depuis le site</h2>
      <p>
        Connecte-toi sur <a href="https://piloo.my-monkey.fr">piloo.my-monkey.fr</a>, puis ouvre tes
        réglages de compte et choisis la suppression.
      </p>

      <h2>Si tu n&apos;as plus l&apos;application</h2>
      <p>
        Écris-nous à <a href="mailto:contact@piloo.fr">contact@piloo.fr</a> depuis l&apos;adresse
        e-mail de ton compte. Nous traitons la demande sous 30 jours au maximum, conformément au
        RGPD.
      </p>

      <h2>Ce qui est supprimé</h2>
      <p>
        Un délai de <strong>7 jours</strong> s&apos;applique avant l&apos;effacement définitif : il
        te suffit de te reconnecter pendant ce délai pour annuler la suppression. Passé ce délai,
        sont effacés ou anonymisés de façon irréversible :
      </p>
      <ul>
        <li>ton identité (nom, prénom, adresse e-mail, téléphone) ;</li>
        <li>tes officines personnelles, tes boîtes et ton inventaire ;</li>
        <li>tes ordonnances, tes prises planifiées et tes rappels ;</li>
        <li>tes préférences et tes sessions de connexion.</li>
      </ul>
      <p>
        Les officines que tu partages avec des proches restent accessibles à leurs autres membres :
        seul ton accès disparaît. Certaines données peuvent être conservées de façon anonymisée
        lorsque la loi l&apos;impose (par exemple des journaux techniques de sécurité), sans
        possibilité de remonter à toi.
      </p>

      <h2>Exporter tes données avant de partir</h2>
      <p>
        Tu peux demander une copie de tes données depuis l&apos;application avant de supprimer ton
        compte. Une fois la suppression effective, cette copie n&apos;est plus récupérable.
      </p>

      <p>
        Pour toute question sur tes données personnelles :{' '}
        <a href="mailto:dpo@piloo.fr">dpo@piloo.fr</a>. Voir aussi notre{' '}
        <a href="/legal/privacy">politique de confidentialité</a>.
      </p>
    </article>
  );
}
