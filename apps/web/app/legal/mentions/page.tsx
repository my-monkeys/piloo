// Mentions légales (#173).
//
// Coordonnées éditeur, hébergeur, directeur de publication. Mises à
// jour dès qu'un de ces éléments change.

export const metadata = {
  title: 'Mentions légales — Piloo',
};

const VERSION = '2026-05-01';

export default function MentionsPage() {
  return (
    <article>
      <p style={{ fontSize: 12, color: '#666' }}>Version : {VERSION}</p>
      <h1>Mentions légales</h1>

      <h2>Éditeur</h2>
      <p>
        Piloo est édité par <strong>My-Monkey</strong>, à compléter avec la forme juridique, le
        siège social, le capital social, le numéro RCS et l'identifiant de TVA intracommunautaire au
        moment du lancement commercial. Pour le POC interne, ces mentions sont laissées en
        placeholder.
      </p>

      <h2>Directeur de publication</h2>
      <p>À compléter avant la mise en ligne publique.</p>

      <h2>Contact</h2>
      <ul>
        <li>
          Support : <a href="mailto:support@piloo.fr">support@piloo.fr</a>
        </li>
        <li>
          Données personnelles : <a href="mailto:dpo@piloo.fr">dpo@piloo.fr</a>
        </li>
        <li>
          Sécurité : <a href="mailto:security@piloo.fr">security@piloo.fr</a>
        </li>
      </ul>

      <h2>Hébergement</h2>
      <p>
        L'application est hébergée chez un prestataire situé au sein de l'Union européenne. La liste
        des sous-traitants est tenue à jour et communiquée sur demande à{' '}
        <a href="mailto:dpo@piloo.fr">dpo@piloo.fr</a>.
      </p>

      <h2>Sources de données</h2>
      <p>
        Les fiches médicaments (DCI, dosage, forme galénique, indications) sont issues de la{' '}
        <strong>Base de Données Publique des Médicaments (BDPM)</strong>, diffusée par les autorités
        sanitaires françaises sous licence ouverte :{' '}
        <a href="https://base-donnees-publique.medicaments.gouv.fr/">
          base-donnees-publique.medicaments.gouv.fr
        </a>
        . Les données sont synchronisées deux fois par jour depuis data.gouv.fr.
      </p>

      <h2>Avertissement</h2>
      <p>
        Piloo est un carnet numérique personnel et un aide-mémoire. Il ne constitue ni un dispositif
        médical au sens du règlement (UE) 2017/745, ni un substitut à l'avis d'un professionnel de
        santé. En cas d'urgence médicale, composez le 15 (Samu) ou le 112.
      </p>

      <p style={{ marginTop: 32 }}>
        <a href="/legal/cgu">CGU</a> · <a href="/legal/privacy">Politique de confidentialité</a>
      </p>
    </article>
  );
}
