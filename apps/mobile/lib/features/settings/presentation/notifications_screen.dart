// Préférences notifications par canal × type (#155).
//
// Pas de maquette dédiée — design en sections par type d'événement,
// chaque section listant les 3 canaux (Push / Email / SMS) avec un
// toggle individuel. Permet à l'utilisateur de choisir finement
// quelle combinaison il veut.
//
// Le SMS sera grisé tant que le numéro de tél n'est pas vérifié
// (futur ticket — pour l'instant, on l'affiche sans état "verrouillé"
// pour la review).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';

enum _Channel { push, email, sms }

enum _NotifType {
  rappelPrise,
  peremption,
  stockBas,
  partage,
  manqueSignale,
}

class _ChannelInfo {
  const _ChannelInfo({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _TypeInfo {
  const _TypeInfo({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // État : map { type => set des canaux activés }. Defaults sains :
  // push partout, email pour les évènements importants seulement, SMS
  // jamais par défaut (coût + permission tél requise).
  final Map<_NotifType, Set<_Channel>> _prefs = {
    _NotifType.rappelPrise: {_Channel.push},
    _NotifType.peremption: {_Channel.push, _Channel.email},
    _NotifType.stockBas: {_Channel.push},
    _NotifType.partage: {_Channel.push, _Channel.email},
    _NotifType.manqueSignale: {_Channel.push},
  };

  static const _channels = {
    _Channel.push: _ChannelInfo(
      label: 'Push',
      icon: PhosphorIconsFill.bellRinging,
    ),
    _Channel.email: _ChannelInfo(
      label: 'Email',
      icon: PhosphorIconsFill.envelope,
    ),
    _Channel.sms: _ChannelInfo(
      label: 'SMS',
      icon: PhosphorIconsFill.chatText,
    ),
  };

  static const _types = [
    (
      type: _NotifType.rappelPrise,
      info: _TypeInfo(
        label: 'Rappel de prise',
        description: 'À l\'heure prévue de chaque prise',
        icon: PhosphorIconsFill.pill,
        color: PilooColors.primary,
      ),
    ),
    (
      type: _NotifType.peremption,
      info: _TypeInfo(
        label: 'Péremption',
        description: 'Quand une boîte va périmer ou est périmée',
        icon: PhosphorIconsFill.warning,
        color: PilooColors.accent,
      ),
    ),
    (
      type: _NotifType.stockBas,
      info: _TypeInfo(
        label: 'Stock bas',
        description: 'Quand il reste peu de doses d\'un médicament',
        icon: PhosphorIconsFill.package,
        color: PilooColors.warningOn,
      ),
    ),
    (
      type: _NotifType.partage,
      info: _TypeInfo(
        label: 'Activité de partage',
        description: 'Invitation acceptée, modifications par un proche',
        icon: PhosphorIconsFill.users,
        color: PilooColors.infoOn,
      ),
    ),
    (
      type: _NotifType.manqueSignale,
      info: _TypeInfo(
        label: 'Manque signalé',
        description: 'Un proche signale un manque dans une officine',
        icon: PhosphorIconsFill.handWaving,
        color: PilooColors.successOn,
      ),
    ),
  ];

  void _toggle(_NotifType type, _Channel channel) {
    setState(() {
      final current = _prefs[type]!;
      if (current.contains(channel)) {
        _prefs[type] = {...current}..remove(channel);
      } else {
        _prefs[type] = {...current, channel};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _IntroText(),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _types.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    _TypeCard(
                      info: _types[i].info,
                      enabledChannels: _prefs[_types[i].type]!,
                      onToggle: (c) => _toggle(_types[i].type, c),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PilooCircleBackButton(),
          Flexible(
            child: Text(
              'Notifications',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _IntroText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Choisis comment Piloo te prévient pour chaque type d\'évènement.',
      style: GoogleFonts.manrope(
        fontSize: 13,
        color: PilooColors.textSecondary,
        height: 1.5,
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.info,
    required this.enabledChannels,
    required this.onToggle,
  });

  final _TypeInfo info;
  final Set<_Channel> enabledChannels;
  final ValueChanged<_Channel> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: PilooColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: info.color.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Icon(info.icon, size: 20, color: info.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.label,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.description,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: PilooColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: PilooColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final c in _Channel.values) ...[
                Expanded(
                  child: _ChannelToggle(
                    channel: c,
                    enabled: enabledChannels.contains(c),
                    onTap: () => onToggle(c),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ChannelToggle extends StatelessWidget {
  const _ChannelToggle({
    required this.channel,
    required this.enabled,
    required this.onTap,
  });

  final _Channel channel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = _NotificationsScreenState._channels[channel]!;
    final fg =
        enabled ? PilooColors.textOnPrimary : PilooColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: enabled ? PilooColors.primary : PilooColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(PilooRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(info.icon, size: 16, color: fg),
            const SizedBox(height: 4),
            Text(
              info.label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
