import 'package:flutter/material.dart';

import '../../theme/circadian_mode.dart';
import '../../theme/unravel_theme.dart';
import '../../theme/unravel_theme_extension.dart';
import '../../theme/unravel_typography.dart';
import '../state/unravel_journal_controller.dart';

/// Unravel Sanctuary (Themes & Sovereign Settings) screen.
///
/// Store & Design Compliance:
/// - Mandatory UI Polish Fix #3: Titles (`Circadian Rhythm Mode`, `Key Held on Device`)
///   wrap cleanly with `softWrap: true` and ZERO `...` ellipses truncation.
/// - Apple Guideline 5.1.1(v): Calm two-step confirmation `"Purge Vault & Delete Cloud Account"`
///   wiping local Drift tables, rotating/destroying device keys, and invoking `delete_my_account()`.
/// - Apple Guideline 1.4.1: Subtle philosophical safe-harbor notice under
///   `Handcrafted Independent Software`.
class SanctuaryScreen extends StatelessWidget {
  const SanctuaryScreen({
    required this.controller,
    super.key,
  });

  final UnravelJournalController controller;

  Future<void> _showTwoStepPurgeConfirmation(BuildContext context) async {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        bool acknowledgeIrreversible = false;
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(void Function()) setDialogState,
          ) {
            return AlertDialog(
              backgroundColor: ext.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UnravelTheme.cardRadius),
                side: BorderSide(color: ext.border, width: 1),
              ),
              title: Text(
                'Purge Vault & Delete Cloud Account?',
                style: typo.eventTitleSerif,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'This permanently erases all local Open Threads, Perspective Logs, '
                    'on-device AES-256-GCM encryption keys, and your synced cloud account (`delete_my_account`).',
                    softWrap: true,
                    style: typo.bodyMedium.copyWith(color: ext.textPrimary),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setDialogState(
                      () =>
                          acknowledgeIrreversible = !acknowledgeIrreversible,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ext.groundingContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ext.border, width: 1),
                      ),
                      child: Row(
                        children: <Widget>[
                          Checkbox(
                            value: acknowledgeIrreversible,
                            activeColor: ext.terracottaAccent,
                            onChanged: (bool? val) => setDialogState(
                              () => acknowledgeIrreversible = val ?? false,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'I understand this purge is immediate and irreversible.',
                              softWrap: true,
                              style: typo.metaMono.copyWith(
                                color: ext.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Keep Sanctuary',
                    style: typo.bodyMedium.copyWith(color: ext.textMuted),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: acknowledgeIrreversible
                        ? ext.terracottaAccent
                        : ext.border,
                    foregroundColor: ext.onPrimaryAccent,
                  ),
                  onPressed: acknowledgeIrreversible
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text('Confirm Permanent Purge'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await controller.purgeVaultAndDeleteCloudAccount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ext.card,
            content: Text(
              'Local vault, encryption keys, and cloud account permanently purged.',
              style: typo.bodyMedium.copyWith(color: ext.textPrimary),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);
    final CircadianPalette activePalette = controller.activePalette;

    return Column(
      children: <Widget>[
        // Top Header Bar
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(
            horizontal: UnravelTheme.screenMargin,
          ),
          decoration: BoxDecoration(
            color: ext.canvas,
            border: Border(bottom: BorderSide(color: ext.border, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.spa_outlined,
                    size: 20,
                    color: ext.primaryAccent,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Sanctuary',
                    style: typo.displaySerif.copyWith(fontSize: 26),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ext.card,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: ext.border, width: 1),
                ),
                child: Text(
                  controller.isFossBuild ? 'FOSS LIBRE' : 'SOVEREIGN',
                  style: typo.metaMono.copyWith(color: ext.primaryAccent),
                ),
              ),
            ],
          ),
        ),

        // Scrollable Sanctuary Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              UnravelTheme.screenMargin,
              18,
              UnravelTheme.screenMargin,
              112,
            ),
            children: <Widget>[
              // 1. Botanical Specimen Stamp & Intro
              Row(
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: ext.primaryAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('PREFERENCES & SOVEREIGNTY', style: typo.metaMono),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Appearance, privacy keys, and intelligence routing.',
                style: typo.bodyMedium,
              ),
              const SizedBox(height: 20),

              // 2. Circadian Rhythm Mode Master Card (Zero Text Truncation!)
              Container(
                padding: const EdgeInsets.all(UnravelTheme.cardPadding),
                decoration: BoxDecoration(
                  color: ext.card,
                  borderRadius: BorderRadius.circular(UnravelTheme.cardRadius),
                  border: Border.all(color: ext.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: ext.groundingContainer,
                            shape: BoxShape.circle,
                            border: Border.all(color: ext.border, width: 1),
                          ),
                          child: Icon(
                            Icons.wb_twilight,
                            size: 18,
                            color: ext.primaryAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Circadian Rhythm Mode',
                                softWrap: true,
                                style: typo.headlineSans.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Automatically shift surfaces with local sunrise, high sun, dusk, and midnight.',
                                softWrap: true,
                                style: typo.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: controller.isCircadianAuto,
                          activeThumbColor: ext.onPrimaryAccent,
                          activeTrackColor: ext.primaryAccent,
                          onChanged: controller.setCircadianAutoEnabled,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ext.groundingContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ext.border, width: 1),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.brightness_6_outlined,
                                size: 15,
                                color: ext.secondaryAccent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${activePalette.displayName} Active',
                                style: typo.metaMono.copyWith(
                                  color: ext.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            controller.nextTransitionSummary,
                            style: typo.metaMono,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UnravelTheme.sectionGap),

              // 3. Circadian Surfaces Swatch Grid (2x2)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('CIRCADIAN SURFACES', style: typo.metaMono),
                  Text('Tap any palette to preview', style: typo.metaMono),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CircadianSwatchCard(
                      palette: CircadianPalette.morningMist,
                      timeLabel: '06:00',
                      subtitle: 'Birch Paper Light',
                      previewCanvas: const Color(0xFFF6F5F0),
                      previewBorder: const Color(0xFFDCD8CE),
                      previewAccent: const Color(0xFF4A6B53),
                      isSelected:
                          activePalette == CircadianPalette.morningMist,
                      onTap: () => controller.selectPaletteManually(
                        CircadianPalette.morningMist,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CircadianSwatchCard(
                      palette: CircadianPalette.highSun,
                      timeLabel: '11:00',
                      subtitle: 'Raw Limestone',
                      previewCanvas: const Color(0xFFEAE8E1),
                      previewBorder: const Color(0xFFCCC8BE),
                      previewAccent: const Color(0xFF3B5944),
                      isSelected: activePalette == CircadianPalette.highSun,
                      onTap: () => controller.selectPaletteManually(
                        CircadianPalette.highSun,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CircadianSwatchCard(
                      palette: CircadianPalette.duskPine,
                      timeLabel: '17:30',
                      subtitle: 'Evening Nature Dark',
                      previewCanvas: const Color(0xFF141815),
                      previewBorder: const Color(0xFF2A332D),
                      previewAccent: const Color(0xFF84A98C),
                      isSelected: activePalette == CircadianPalette.duskPine,
                      onTap: () => controller.selectPaletteManually(
                        CircadianPalette.duskPine,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CircadianSwatchCard(
                      palette: CircadianPalette.midnightStarlight,
                      timeLabel: '23:00',
                      subtitle: 'Pure OLED Black',
                      previewCanvas: const Color(0xFF000000),
                      previewBorder: const Color(0xFF222623),
                      previewAccent: const Color(0xFF749C82),
                      isSelected:
                          activePalette == CircadianPalette.midnightStarlight,
                      onTap: () => controller.selectPaletteManually(
                        CircadianPalette.midnightStarlight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: UnravelTheme.sectionGap),

              // 4. Sovereign Data Vault (Zero Text Truncation on `Key Held on Device`!)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('SOVEREIGN DATA VAULT', style: typo.metaMono),
                  Text(
                    'Zero-Knowledge',
                    style: typo.metaMono.copyWith(
                      color: ext.secondaryAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(UnravelTheme.cardPadding),
                decoration: BoxDecoration(
                  color: ext.card,
                  borderRadius: BorderRadius.circular(UnravelTheme.cardRadius),
                  border: Border.all(color: ext.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Storage Architecture', style: typo.eventTitleSerif),
                    const SizedBox(height: 4),
                    Text(
                      'Your reflections are encrypted on-device without corporate telemetry.',
                      softWrap: true,
                      style: typo.bodyMedium,
                    ),
                    const SizedBox(height: 14),

                    // 3-Way Segmented Control
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ext.groundingContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ext.border, width: 1),
                      ),
                      child: Row(
                        children: <Widget>[
                          for (final StorageArchitectureMode mode
                              in StorageArchitectureMode.values)
                            Expanded(
                              child: GestureDetector(
                                onTap: () => controller.setStorageMode(mode),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: controller.storageMode == mode
                                        ? ext.canvas
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: controller.storageMode == mode
                                        ? Border.all(
                                            color: ext.border,
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    mode.label,
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                    style: typo.metaMono.copyWith(
                                      color: controller.storageMode == mode
                                          ? ext.textPrimary
                                          : ext.textMuted,
                                      fontWeight: controller.storageMode == mode
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Security Status Box (Wraps cleanly without `...` ellipses!)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ext.groundingContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ext.border, width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: ext.card,
                              shape: BoxShape.circle,
                              border: Border.all(color: ext.border, width: 1),
                            ),
                            child: Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: ext.primaryAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        'End-to-End Encrypted',
                                        softWrap: true,
                                        style: typo.settingTitleSans,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.verified_user_outlined,
                                      size: 15,
                                      color: ext.primaryAccent,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'AES-256-GCM · Key Held on Device',
                                  softWrap: true,
                                  style: typo.metaMono.copyWith(
                                    color: ext.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Backup Seed / Argon2id Key Bundle Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: ext.card,
                              content: Text(
                                'Master Data Key wrapped via Argon2id on-device.',
                                style: typo.bodyMedium.copyWith(
                                  color: ext.textPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.key_outlined,
                          size: 18,
                          color: ext.secondaryAccent,
                        ),
                        label: Text(
                          'Export Seed Recovery Phrase (12 Words)',
                          style: typo.bodyMedium.copyWith(
                            color: ext.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Apple App Store Guideline 5.1.1(v) Compliance:
                    // Calm, two-step confirmation "Purge Vault & Delete Cloud Account"
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showTwoStepPurgeConfirmation(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: ext.terracottaAccent.withValues(alpha: 0.65),
                            width: 1,
                          ),
                        ),
                        icon: Icon(
                          Icons.delete_forever_outlined,
                          size: 18,
                          color: ext.terracottaAccent,
                        ),
                        label: Text(
                          'Purge Vault & Delete Cloud Account',
                          style: typo.bodyMedium.copyWith(
                            color: ext.terracottaAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UnravelTheme.sectionGap),

              // 5. Intelligence Routing Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('INTELLIGENCE ROUTING', style: typo.metaMono),
                  Text(
                    'Privacy-Preserved',
                    style: typo.metaMono.copyWith(
                      color: ext.primaryAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(UnravelTheme.cardPadding),
                decoration: BoxDecoration(
                  color: ext.card,
                  borderRadius: BorderRadius.circular(UnravelTheme.cardRadius),
                  border: Border.all(color: ext.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Cognitive Reframing Assistant',
                      style: typo.eventTitleSerif,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select how philosophical inquiries and worry untangling prompts are processed.',
                      softWrap: true,
                      style: typo.bodyMedium,
                    ),
                    const SizedBox(height: 14),

                    if (!controller.isFossBuild) ...<Widget>[
                      _IntelligenceOptionTile(
                        title: 'Managed Multi-Model Relay',
                        description:
                            'Stateless entitlement-gated routing. Zero prompt training, zero retention.',
                        isSelected: controller.intelligenceMode ==
                            IntelligenceRoutingMode.managedMultiModelRelay,
                        onTap: () => controller.setIntelligenceMode(
                          IntelligenceRoutingMode.managedMultiModelRelay,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    _IntelligenceOptionTile(
                      title: 'Bring Your Own Key or Local Daemon',
                      description:
                          'Connect directly via personal API key or air-gapped local Ollama server (http://localhost:11434).',
                      isSelected: controller.intelligenceMode ==
                          IntelligenceRoutingMode.byokOrLocalDaemon,
                      onTap: () => controller.setIntelligenceMode(
                        IntelligenceRoutingMode.byokOrLocalDaemon,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UnravelTheme.sectionGap),

              // 6. Botanical Field Note Quote
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ext.card,
                  borderRadius: BorderRadius.circular(UnravelTheme.cardRadius),
                  border: Border.all(color: ext.border, width: 1),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ext.groundingContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: ext.border, width: 1),
                      ),
                      child: Icon(
                        Icons.energy_savings_leaf_outlined,
                        size: 20,
                        color: ext.primaryAccent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '“Quiet tools cultivate quiet minds.”',
                            softWrap: true,
                            style: typo.transcriptSerifItalic,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'FIELD JOURNAL PRINCIPLE § 04',
                            style: typo.metaMono.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 7. Handcrafted Independent Software + Philosophical Safe-Harbor Notice (Apple 1.4.1)
              Container(
                padding: const EdgeInsets.all(UnravelTheme.cardPadding),
                decoration: BoxDecoration(
                  color: ext.card,
                  borderRadius: BorderRadius.circular(UnravelTheme.cardRadius),
                  border: Border.all(color: ext.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ext.groundingContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: ext.border, width: 1),
                      ),
                      child: Icon(
                        Icons.spa_outlined,
                        size: 20,
                        color: ext.primaryAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Handcrafted Independent Software',
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: typo.eventTitleSerif.copyWith(fontSize: 19),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Unravel is free of tracking pixels, engagement traps, and venture obligations. Made for slow contemplation.',
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: typo.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    Divider(color: ext.border, height: 1),
                    const SizedBox(height: 12),
                    // Subtle Philosophical Safe-Harbor Notice (Apple 1.4.1)
                    Text(
                      'Philosophical Safe-Harbor Notice · Unravel is a Stoic and botanical field journal for personal contemplation, not a medical device, clinical diagnostic tool, or substitute for professional mental health care. If you are experiencing a crisis, please contact your local emergency services or a crisis support helpline.',
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: typo.metaMono.copyWith(
                        fontSize: 10.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quiet Release Stamp
              Center(
                child: Column(
                  children: <Widget>[
                    Text(
                      'Unravel v0.1.0 · Birchwood Release',
                      style: typo.metaMono,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Local Drift SQLite · 100% Offline Capable · Zero Streaks',
                      style: typo.metaMono.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircadianSwatchCard extends StatelessWidget {
  const _CircadianSwatchCard({
    required this.palette,
    required this.timeLabel,
    required this.subtitle,
    required this.previewCanvas,
    required this.previewBorder,
    required this.previewAccent,
    required this.isSelected,
    required this.onTap,
  });

  final CircadianPalette palette;
  final String timeLabel;
  final String subtitle;
  final Color previewCanvas;
  final Color previewBorder;
  final Color previewAccent;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ext.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? ext.primaryAccent : ext.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 58,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: previewCanvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: previewBorder, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: previewAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        isSelected ? 'CURRENT' : timeLabel,
                        style: typo.metaMono.copyWith(
                          fontSize: 9,
                          color: previewAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 32,
                    height: 5,
                    decoration: BoxDecoration(
                      color: previewAccent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              palette.displayName,
              softWrap: true,
              style: typo.settingTitleSans.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              softWrap: true,
              style: typo.metaMono.copyWith(
                fontSize: 10,
                color: isSelected ? ext.primaryAccent : ext.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntelligenceOptionTile extends StatelessWidget {
  const _IntelligenceOptionTile({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? ext.groundingContainer : ext.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ext.primaryAccent : ext.border,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 18,
              color: isSelected ? ext.primaryAccent : ext.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    softWrap: true,
                    style: typo.settingTitleSans.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    softWrap: true,
                    style: typo.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
