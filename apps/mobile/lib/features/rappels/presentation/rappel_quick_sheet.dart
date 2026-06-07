// Modale "Rappel rapide" (#98).
// 4 toggles matin/midi/soir/coucher avec champ numérique inline (1-99).
// Au moins un moment doit avoir une quantité — sinon le bouton créer
// reste désactivé (cf. validation back qui rejette aussi).
//
// Pas de bouton "date début / fin" sur ce premier ship : on prend
// today comme date_debut, date_fin null (rappel sans fin). UI plus
// avancée = follow-up.
//
// B5 : mode édition (initial != null) — préremplit les champs depuis
// un rappel existant et adapte les libellés. Le champ notes est ajouté
// pour les deux modes (création + édition).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:piloo_api_client/piloo_api_client.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

/// Durée d'un rappel. `null` = à vie (date_fin nullable côté DB).
/// Sinon, nombre de jours à ajouter à dateDebut pour calculer dateFin.
enum RappelDuree {
  uneSemaine(7, '1 semaine'),
  unMois(30, '1 mois'),
  troisMois(90, '3 mois'),
  sixMois(180, '6 mois'),
  unAn(365, '1 an'),
  aVie(null, 'À vie');

  const RappelDuree(this.jours, this.label);
  final int? jours;
  final String label;
}

class RappelQuickResult {
  const RappelQuickResult({
    required this.matin,
    required this.midi,
    required this.soir,
    required this.coucher,
    required this.unite,
    required this.duree,
    this.notes,
  });

  final int? matin;
  final int? midi;
  final int? soir;
  final int? coucher;
  final String unite;
  final RappelDuree duree;
  final String? notes;

  bool get hasAtLeastOneMoment =>
      matin != null || midi != null || soir != null || coucher != null;
}

/// Ouvre la modale. Retourne le résultat saisi (ou null si annulé).
/// Passer [initial] pour ouvrir en mode édition (préremplit les champs
/// depuis le rappel existant et adapte les libellés).
Future<RappelQuickResult?> showRappelQuickSheet(
  BuildContext context, {
  required String medicamentName,

  /// Unité par défaut (BDPM doseUnit si dispo, sinon 'comprimé').
  String suggestedUnite = 'comprimé',
  Rappel? initial,
}) {
  return showModalBottomSheet<RappelQuickResult>(
    context: context,
    backgroundColor: PilooColors.background,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RappelQuickSheet(
      medicamentName: medicamentName,
      suggestedUnite: suggestedUnite,
      initial: initial,
    ),
  );
}

class _RappelQuickSheet extends StatefulWidget {
  const _RappelQuickSheet({
    required this.medicamentName,
    required this.suggestedUnite,
    this.initial,
  });

  final String medicamentName;
  final String suggestedUnite;
  final Rappel? initial;

  @override
  State<_RappelQuickSheet> createState() => _RappelQuickSheetState();
}

class _RappelQuickSheetState extends State<_RappelQuickSheet> {
  // null = moment non coché. Quand on coche, on initialise à 1 par défaut.
  int? _matin;
  int? _midi;
  int? _soir;
  int? _coucher;
  // Défaut "à vie" : couvre le cas le plus fréquent (médoc chronique).
  // L'user peut ajuster pour les cures ponctuelles (antibio = 1 semaine).
  RappelDuree _duree = RappelDuree.aVie;

  late final TextEditingController _notesCtrl;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      // Préremplit les quantités depuis le rappel existant.
      _matin = initial.quantiteMatin;
      _midi = initial.quantiteMidi;
      _soir = initial.quantiteSoir;
      _coucher = initial.quantiteCoucher;
      _notesCtrl = TextEditingController(text: initial.notes ?? '');
      // Dérive la durée depuis les dates (LOSSLESS — les rappels sont
      // toujours créés avec dateFin = dateDebut + duree.jours).
      final fin = initial.dateFin;
      if (fin == null) {
        _duree = RappelDuree.aVie;
      } else {
        final debut = initial.dateDebut;
        // UTC pour éviter les décalages DST lors du calcul en jours.
        final debutDt = DateTime.utc(debut.year, debut.month, debut.day);
        final finDt = DateTime.utc(fin.year, fin.month, fin.day);
        final days = finDt.difference(debutDt).inDays;
        _duree = RappelDuree.values.firstWhere(
          (d) => d.jours == days,
          // Durée non standard (ex: créée depuis le web) → À vie.
          orElse: () => RappelDuree.aVie,
        );
      }
    } else {
      _notesCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _matin != null || _midi != null || _soir != null || _coucher != null;

  void _toggle(String key, bool on) {
    setState(() {
      final defaultQty = on ? 1 : null;
      switch (key) {
        case 'matin':
          _matin = defaultQty;
        case 'midi':
          _midi = defaultQty;
        case 'soir':
          _soir = defaultQty;
        case 'coucher':
          _coucher = defaultQty;
      }
    });
  }

  void _setQty(String key, int qty) {
    final clamped = qty.clamp(1, 99);
    setState(() {
      switch (key) {
        case 'matin':
          _matin = clamped;
        case 'midi':
          _midi = clamped;
        case 'soir':
          _soir = clamped;
        case 'coucher':
          _coucher = clamped;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Padding bottom adaptatif au clavier — la sheet contient des
    // TextField qui ne doivent pas être masqués quand le keyboard monte.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + keyboardInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: PilooColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _Header(name: widget.medicamentName, isEditing: _isEditing),
            const SizedBox(height: 16),
            _MomentRow(
              icon: PhosphorIconsRegular.sun,
              label: 'Matin',
              qty: _matin,
              unite: widget.suggestedUnite,
              onToggle: (v) => _toggle('matin', v),
              onQtyChange: (n) => _setQty('matin', n),
            ),
            const SizedBox(height: 8),
            _MomentRow(
              icon: PhosphorIconsRegular.sunHorizon,
              label: 'Midi',
              qty: _midi,
              unite: widget.suggestedUnite,
              onToggle: (v) => _toggle('midi', v),
              onQtyChange: (n) => _setQty('midi', n),
            ),
            const SizedBox(height: 8),
            _MomentRow(
              icon: PhosphorIconsRegular.cloudSun,
              label: 'Soir',
              qty: _soir,
              unite: widget.suggestedUnite,
              onToggle: (v) => _toggle('soir', v),
              onQtyChange: (n) => _setQty('soir', n),
            ),
            const SizedBox(height: 8),
            _MomentRow(
              icon: PhosphorIconsRegular.moon,
              label: 'Coucher',
              qty: _coucher,
              unite: widget.suggestedUnite,
              onToggle: (v) => _toggle('coucher', v),
              onQtyChange: (n) => _setQty('coucher', n),
            ),
            const SizedBox(height: 16),
            _DureeSelector(
              value: _duree,
              onChange: (d) => setState(() => _duree = d),
            ),
            const SizedBox(height: 16),
            _NotesField(controller: _notesCtrl),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _PrimaryButton(
                    label: _isEditing ? 'Enregistrer' : 'Créer le rappel',
                    onTap: _canSubmit
                        ? () => Navigator.of(context).pop(
                            RappelQuickResult(
                              matin: _matin,
                              midi: _midi,
                              soir: _soir,
                              coucher: _coucher,
                              unite: widget.suggestedUnite,
                              duree: _duree,
                              notes: _notesCtrl.text.trim().isEmpty
                                  ? null
                                  : _notesCtrl.text.trim(),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.isEditing});
  final String name;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PilooColors.primarySoft,
              borderRadius: BorderRadius.circular(PilooRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsFill.bell,
              size: 22,
              color: PilooColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'MODIFIER LE RAPPEL' : 'NOUVEAU RAPPEL',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: PilooColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({
    required this.icon,
    required this.label,
    required this.qty,
    required this.unite,
    required this.onToggle,
    required this.onQtyChange,
  });

  final IconData icon;
  final String label;
  final int? qty;
  final String unite;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onQtyChange;

  bool get _on => qty != null;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PilooColors.surface,
      borderRadius: BorderRadius.circular(PilooRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        onTap: () => onToggle(!_on),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PilooRadius.lg),
            border: Border.all(
              color: _on ? PilooColors.primary : PilooColors.border,
              width: _on ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _on
                      ? PilooColors.primarySoft
                      : PilooColors.surfaceSubtle,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 18,
                  color: _on ? PilooColors.primary : PilooColors.textTertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _on
                        ? PilooColors.textPrimary
                        : PilooColors.textSecondary,
                  ),
                ),
              ),
              if (_on)
                _QtyStepper(value: qty!, unite: unite, onChange: onQtyChange)
              else
                Text(
                  'Aucune',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: PilooColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.unite,
    required this.onChange,
  });

  final int value;
  final String unite;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    // Empilement vertical chiffre / unité pour éviter le wrap de mots
    // longs ("comprimé", "gélule"…) sur 2 lignes quand la largeur dispo
    // est étroite. Unité toujours au singulier (cohérent avec le format
    // "1 comprimé" → "2 comprimé" lisible et compact).
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _StepBtn(
          icon: PhosphorIconsRegular.minus,
          onTap: value > 1 ? () => onChange(value - 1) : null,
        ),
        SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: PilooColors.textPrimary,
                  height: 1.1,
                ),
              ),
              Text(
                unite,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  color: PilooColors.textTertiary,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        _StepBtn(
          icon: PhosphorIconsRegular.plus,
          onTap: value < 99 ? () => onChange(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: PilooColors.surfaceSubtle,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: disabled
                ? PilooColors.textTertiary
                : PilooColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: disabled ? PilooColors.surfaceSubtle : PilooColors.primary,
      borderRadius: BorderRadius.circular(PilooRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(PilooRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: disabled ? PilooColors.textTertiary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de durée du rappel (7j / 30j / 90j / 180j / 365j / à vie).
/// Présenté comme une grille de pills 2 lignes × 3, l'option active
/// avec border primary + bg primarySoft. "À vie" est l'option par
/// défaut (cas chronique le plus fréquent).
class _DureeSelector extends StatelessWidget {
  const _DureeSelector({required this.value, required this.onChange});

  final RappelDuree value;
  final ValueChanged<RappelDuree> onChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DURÉE',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: PilooColors.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in RappelDuree.values)
              _DureePill(
                label: d.label,
                active: d == value,
                onTap: () => onChange(d),
              ),
          ],
        ),
      ],
    );
  }
}

class _DureePill extends StatelessWidget {
  const _DureePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? PilooColors.primarySoft : PilooColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? PilooColors.primary : PilooColors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? PilooColors.primary : PilooColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTES',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: PilooColors.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: PilooColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Notes (optionnel)',
            hintStyle: GoogleFonts.manrope(
              fontSize: 14,
              color: PilooColors.textTertiary,
            ),
            filled: true,
            fillColor: PilooColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PilooRadius.lg),
              borderSide: const BorderSide(color: PilooColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PilooRadius.lg),
              borderSide: const BorderSide(color: PilooColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PilooRadius.lg),
              borderSide: const BorderSide(
                color: PilooColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(PilooRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(PilooRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PilooRadius.md),
            border: Border.all(color: PilooColors.border),
          ),
          alignment: Alignment.center,
          child: Text(
            'Annuler',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: PilooColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
