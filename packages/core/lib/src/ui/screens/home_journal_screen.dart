import 'package:flutter/material.dart';

import '../../database/tables.dart';
import '../../database/unravel_database.dart';
import '../../theme/unravel_theme.dart';
import '../../theme/unravel_theme_extension.dart';
import '../../theme/unravel_typography.dart';
import '../sheets/unravel_knot_sheet.dart';
import '../state/unravel_journal_controller.dart';
import '../widgets/perspective_curve_painter.dart';

String _eventWhenLabel(DateTime when) {
  final Duration delta = when.difference(DateTime.now());
  if (delta.isNegative) {
    return 'READY FOR CHECK-IN';
  }
  if (delta.inDays >= 1) {
    final int days = delta.inDays;
    return 'UPCOMING · IN $days ${days == 1 ? 'DAY' : 'DAYS'}';
  }
  if (delta.inHours >= 1) {
    final int hours = delta.inHours;
    return 'UPCOMING · IN $hours ${hours == 1 ? 'HOUR' : 'HOURS'}';
  }
  return 'UPCOMING · SOON';
}

/// Unravel Home Journal screen.
///
/// Mandatory UI Polish Fix applied:
/// - Keeps ONLY the lower Circadian sun pill (`Dawn · 7:15 AM` / `Dusk · 6:45 PM`)
///   and removes the redundant clock pill in the top-right app bar.
/// - Replaces the Stitch mockup's external Google avatar URL with an offline
///   botanical emblem so F-Droid builds never make background network requests.
class HomeJournalScreen extends StatelessWidget {
  const HomeJournalScreen({
    required this.controller,
    required this.onNavigateToSanctuary,
    super.key,
  });

  final UnravelJournalController controller;
  final VoidCallback onNavigateToSanctuary;

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);
    final List<OpenThreadRecord> activeThreads = controller.activeOpenThreads;

    return Column(
      children: <Widget>[
        // Top App Bar (No redundant top-right clock pill!)
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
              Flexible(
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ext.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: ext.border, width: 1),
                      ),
                      child: Icon(
                        Icons.eco_outlined,
                        size: 17,
                        color: ext.primaryAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Unravel',
                      style: typo.displaySerif.copyWith(fontSize: 26),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        ext.palette.displayName.toUpperCase(),
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: typo.metaMono,
                      ),
                    ),
                  ],
                ),
              ),
              // Sovereign offline profile/sanctuary shortcut (zero network requests)
              InkWell(
                borderRadius: BorderRadius.circular(9999),
                onTap: onNavigateToSanctuary,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: ext.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: ext.border, width: 1),
                  ),
                  child: Icon(
                    Icons.spa_outlined,
                    size: 17,
                    color: ext.primaryAccent,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main Scrollable Field Journal
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              UnravelTheme.screenMargin,
              18,
              UnravelTheme.screenMargin,
              112,
            ),
            children: <Widget>[
              // 1. Single Lower Circadian Sun Pill & Daily Quote Banner
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ext.card,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: ext.border, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          ext.isDark
                              ? Icons.nights_stay_outlined
                              : Icons.wb_twilight,
                          size: 14,
                          color: ext.secondaryAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(controller.sunPillLabel, style: typo.metaMono),
                      ],
                    ),
                  ),
                  Text(
                    'QUIET MIND',
                    style: typo.metaMono.copyWith(
                      color: ext.secondaryAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Daily Philosophical Quote Card
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.energy_savings_leaf_outlined,
                              size: 16,
                              color: ext.primaryAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ext.isDark
                                  ? 'EVENING REFLECTION'
                                  : 'MORNING REFLECTION',
                              style: typo.metaMono,
                            ),
                          ],
                        ),
                        Text('Solace & Grounding', style: typo.metaMono),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '“We suffer more often in imagination than in reality.”',
                      style: typo.quoteSerifItalic,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '— Seneca',
                          style: typo.metaMono.copyWith(
                            color: ext.primaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text('Letters from a Stoic', style: typo.metaMono),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UnravelTheme.sectionGap),

              // 2. Active Open Thread Card (Hero Card)
              if (activeThreads.isEmpty)
                Text(
                  'No open threads yet. Hold the pill below, name the moment, then save it.',
                  style: typo.bodyMedium,
                )
              else
                for (final OpenThreadRecord thread in activeThreads) ...<Widget>[
                  _OpenThreadHeroCard(
                    thread: thread,
                    onCheckInTap: () => showUnravelKnotSheet(
                      context: context,
                      controller: controller,
                      initialMode: ReflectionSheetMode.afterMoment,
                      initialThreadForCheckIn: thread,
                    ),
                  ),
                  const SizedBox(height: UnravelTheme.sectionGap),
                ],

              // 3. Perspective Curve Card ("What Fear Predicted vs. How Life Unfolded")
              _PerspectiveCurveCard(controller: controller),
              const SizedBox(height: UnravelTheme.sectionGap),

              // 4. Recent Stillness (Resolved Threads Grid)
              _RecentStillnessSection(
                unraveledThreads: controller.unraveledThreads,
              ),
              const SizedBox(height: 28),

              // Botanical Micro-Presence Footer
              Center(
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.spa_outlined,
                      size: 22,
                      color: ext.primaryAccent.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'THE MIND SETTLES WHEN SEEN CLEARLY',
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

class _OpenThreadHeroCard extends StatelessWidget {
  const _OpenThreadHeroCard({
    required this.thread,
    required this.onCheckInTap,
  });

  final OpenThreadRecord thread;
  final VoidCallback onCheckInTap;

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ext.groundingContainer,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: ext.border, width: 1),
                ),
                child: Text(
                  _eventWhenLabel(thread.eventOccursAt),
                  style: typo.metaMono.copyWith(
                    color: ext.secondaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ext.secondaryAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            thread.eventTitle,
            style: typo.displaySerif.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Untangled Worries (${thread.worries.length})',
                style: typo.bodyMedium,
              ),
              Text(
                'Unwound',
                style: typo.metaMono.copyWith(
                  color: ext.primaryAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final UnraveledWorryItem worry in thread.worries) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ext.canvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ext.border, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(worry.indexNumber, style: typo.worryIndexMono),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          worry.worryText,
                          style: typo.bodyMedium.copyWith(
                            color: ext.textPrimary,
                          ),
                        ),
                        if (worry.actionOrGrounding.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            '${worry.controlScope.actionPrefix}: ${worry.actionOrGrounding}',
                            style: typo.metaMono.copyWith(
                              color: worry.controlScope ==
                                      WorryControlScope.withinMyControl
                                  ? ext.primaryAccent
                                  : ext.secondaryAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),

          // Grounding Anchor Callout Box (`#242B26` in Dusk Pine)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ext.groundingContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ext.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.filter_vintage_outlined,
                      size: 16,
                      color: ext.primaryAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'GROUNDING ANCHOR',
                      style: typo.metaMono.copyWith(
                        color: ext.primaryAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  thread.groundingAnchor,
                  style: typo.transcriptSerifItalic,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary Action Pill Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCheckInTap,
              icon: const Text('Check In After Moment'),
              label: const Icon(Icons.arrow_forward, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerspectiveCurveCard extends StatelessWidget {
  const _PerspectiveCurveCard({required this.controller});

  final UnravelJournalController controller;

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);
    final List<PerspectiveCurveEntry> entries = controller.perspectiveEntries;
    final PerspectiveCurveEntry? latest =
        entries.isNotEmpty ? entries.last : null;
    final int gentlerPct = controller.gentlerThanFearedPercentage;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Text(
                  'Perspective Curve',
                  style: typo.eventTitleSerif,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ext.primaryContainer,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: ext.border, width: 1),
                ),
                child: Text(
                  '$gentlerPct% gentler than feared',
                  style: typo.metaMono.copyWith(
                    color: ext.primaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'What Fear Predicted vs. How Life Unfolded',
            style: typo.bodyMedium,
          ),
          const SizedBox(height: 14),

          // Dual Spline Graph
          PerspectiveCurveChart(entries: entries),
          const SizedBox(height: 10),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 2,
                    color: ext.fearPredictedLine,
                  ),
                  const SizedBox(width: 6),
                  Text('What Fear Predicted', style: typo.metaMono),
                ],
              ),
              Row(
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 3,
                    decoration: BoxDecoration(
                      color: ext.lifeUnfoldedLine,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'How Life Unfolded',
                    style: typo.metaMono.copyWith(
                      color: ext.primaryAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Recent Unraveled Thread Callout
          if (latest != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ext.groundingContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ext.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          '“${latest.eventTitle}”',
                          style: typo.settingTitleSans.copyWith(fontSize: 14),
                        ),
                      ),
                      Text(
                        'FEAR: ${latest.predictedFear}/10 → OUTCOME: ${latest.actualOutcome}/10',
                        style: typo.metaMono.copyWith(
                          color: ext.primaryAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '“${latest.decryptedNotes}”',
                    style: typo.transcriptSerifItalic.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentStillnessSection extends StatelessWidget {
  const _RecentStillnessSection({required this.unraveledThreads});

  final List<OpenThreadRecord> unraveledThreads;

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('RECENT STILLNESS', style: typo.metaMono),
            Text(
              '${unraveledThreads.length} Unraveled',
              style: typo.metaMono.copyWith(color: ext.primaryAccent),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            for (int i = 0;
                i < unraveledThreads.take(2).length;
                i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ext.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ext.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text('RESOLVED', style: typo.metaMono),
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: ext.primaryAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        unraveledThreads[i].eventTitle,
                        style: typo.settingTitleSans.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gentler than feared',
                        style: typo.metaMono.copyWith(
                          fontSize: 10,
                          color: ext.secondaryAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
