// CGU — Conditions Générales d'Utilisation (#173).
//
// Version source ligne 1 : `2026-05-01`. Toute modification doit faire
// l'objet d'un commit séparé pour conserver l'historique opposable.

export const metadata = {
  title: "Conditions générales d'utilisation — Piloo",
};

const VERSION = '2026-05-01';

export default function CguPage() {
  return (
    <article>
      <p className="legal-version">Version : {VERSION}</p>
      <h1>Conditions générales d'utilisation</h1>

      <h2>1. Objet</h2>
      <p>
        Les présentes conditions régissent l'utilisation de l'application Piloo, carnet numérique
        personnel de médicaments. Piloo permet à un utilisateur d'enregistrer ses boîtes de
        médicaments, de visualiser leurs dates de péremption, de programmer des rappels de prise et
        de partager son officine avec ses proches.
      </p>

      <h2>2. Nature du service</h2>
      <p>
        <strong>Piloo n'est pas un dispositif médical au sens du règlement (UE) 2017/745.</strong>{' '}
        L'application est un aide-mémoire personnel ; elle ne fournit aucun diagnostic, aucune
        recommandation thérapeutique, aucune validation clinique des prescriptions. Elle ne remplace
        ni l'ordonnance officielle d'un médecin, ni l'avis d'un pharmacien.
      </p>
      <p>
        L'utilisateur reste seul responsable de la conformité de ses prises avec sa prescription
        médicale. En cas de doute sur un médicament, sa posologie ou une interaction, il doit
        consulter un professionnel de santé.
      </p>

      <h2>3. Compte et accès</h2>
      <p>
        L'inscription est gratuite. Pour créer un compte, l'utilisateur fournit une adresse email
        valide et un mot de passe. Il s'engage à conserver ses identifiants confidentiels et à
        notifier sans délai tout accès non autorisé à{' '}
        <a href="mailto:support@piloo.fr">support@piloo.fr</a>.
      </p>

      <h2>4. Utilisation acceptable</h2>
      <ul>
        <li>
          L'utilisateur ne saisit que ses propres données ou celles de proches qui lui ont donné
          leur consentement explicite.
        </li>
        <li>
          L'utilisateur ne se sert pas de Piloo pour diffuser des contenus illicites, contrefaisants
          ou portant atteinte à la vie privée d'autrui.
        </li>
        <li>
          Toute tentative de contournement des limites d'accès, de scraping massif des données, ou
          d'exploitation de vulnérabilités peut entraîner la fermeture immédiate du compte.
        </li>
      </ul>

      <h2>5. Partage d'officine</h2>
      <p>
        Un utilisateur peut inviter d'autres personnes à accéder à son officine avec l'un des trois
        rôles : Propriétaire, Éditeur ou Lecteur. Le Propriétaire peut révoquer un partage à tout
        moment. Les invitations en attente expirent au bout de 30 jours.
      </p>

      <h2>6. Disponibilité du service</h2>
      <p>
        Piloo s'efforce d'assurer une disponibilité maximale du service mais ne garantit pas un
        fonctionnement ininterrompu. Des opérations de maintenance peuvent être effectuées à tout
        moment et sans préavis. L'utilisateur reconnaît que l'application est conçue pour
        fonctionner hors-ligne (offline-first) et qu'une absence temporaire de réseau ne constitue
        pas un dysfonctionnement.
      </p>

      <h2>7. Propriété intellectuelle</h2>
      <p>
        Le code, les marques, les éléments graphiques et les bases de données développées par Piloo
        restent la propriété exclusive de l'éditeur. La base BDPM (Base de Données Publique des
        Médicaments) intégrée à Piloo est diffusée sous licence ouverte par les autorités sanitaires
        françaises ; elle est consultable sur{' '}
        <a href="https://base-donnees-publique.medicaments.gouv.fr/">
          base-donnees-publique.medicaments.gouv.fr
        </a>
        .
      </p>

      <h2>8. Données personnelles</h2>
      <p>
        Le traitement des données personnelles est décrit dans la{' '}
        <a href="/legal/privacy">politique de confidentialité</a>.
      </p>

      <h2>9. Limitation de responsabilité</h2>
      <p>
        Piloo ne saurait être tenu responsable des conséquences d'une utilisation non conforme à
        l'objet du service, en particulier d'une mauvaise prise médicamenteuse résultant d'une
        erreur de saisie de l'utilisateur ou de son non-respect d'une consigne médicale.
      </p>

      <h2>10. Modification des CGU</h2>
      <p>
        Les CGU peuvent être modifiées. Les utilisateurs sont informés des changements substantiels
        par email et lors de leur prochaine connexion. La poursuite de l'utilisation après
        notification vaut acceptation.
      </p>

      <h2>11. Droit applicable</h2>
      <p>
        Les présentes CGU sont régies par le droit français. Tout litige relève de la compétence
        exclusive des tribunaux du ressort du siège social de l'éditeur, sous réserve des
        dispositions impératives du code de la consommation.
      </p>

      <p style={{ marginTop: 32 }}>
        <a href="/legal/privacy">Politique de confidentialité</a> ·{' '}
        <a href="/legal/mentions">Mentions légales</a>
      </p>
    </article>
  );
}
