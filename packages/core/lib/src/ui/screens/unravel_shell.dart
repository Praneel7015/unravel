import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/unravel_database.dart';
import '../../interfaces/sync_and_relay_interfaces.dart';
import '../../theme/circadian_mode.dart';
import '../../theme/unravel_theme.dart';
import '../../theme/unravel_theme_extension.dart';
import '../../theme/unravel_typography.dart';
import '../sheets/unravel_knot_sheet.dart';
import '../state/unravel_journal_controller.dart';
import 'home_journal_screen.dart';
import 'sanctuary_screen.dart';
import 'setup_flow_screen.dart';
import 'thread_wizard_screen.dart';

/// Top-level Unravel application widget shared by `unravel_foss` and `unravel_store`.
class UnravelApp extends StatefulWidget {
  const UnravelApp({
    required this.syncEngine,
    required this.isFossBuild,
    this.initialThemePreference = CircadianThemePreference.circadianAuto,
    this.controller,
    this.publicSiteOrigin = '',
    super.key,
  });

  final UnravelSyncEngine syncEngine;
  final bool isFossBuild;
  final CircadianThemePreference initialThemePreference;
  final UnravelJournalController? controller;

  /// Empty until `--dart-define=PUBLIC_SITE_ORIGIN=` names a real host.
  final String publicSiteOrigin;

  @override
  State<UnravelApp> createState() => _UnravelAppState();
}

class _UnravelAppState extends State<UnravelApp> {
  late final UnravelJournalController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    // Hide the phone navigation bar and leave room for the keyboard.
    // immersiveSticky keeps the keyboard from sitting above a text field.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[SystemUiOverlay.top],
    );
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = UnravelJournalController(
        syncEngine: widget.syncEngine,
        isFossBuild: widget.isFossBuild,
        initialThemePreference: widget.initialThemePreference,
        database: UnravelDatabase(),
        publicSiteOrigin: widget.publicSiteOrigin,
      );
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? _) {
        final ThemeData theme = UnravelTheme.forPalette(
          _controller.activePalette,
        );
        return MaterialApp(
          title: 'Unravel',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: !_controller.vaultReady
              ? Scaffold(backgroundColor: theme.scaffoldBackgroundColor)
              : !_controller.setupComplete
                  ? SetupFlow(controller: _controller)
                  : _controller.needsUnlock
                      ? UnlockJournalScreen(controller: _controller)
                      : UnravelShell(controller: _controller),
        );
      },
    );
  }
}

/// 3-tab bottom navigation shell (`Journal`, `Unravel`, `Sanctuary`) with the
/// floating "Hold to Unravel a Worry" botanical pill button and notification
/// deep-link listener for "After a Moment" check-ins.
class UnravelShell extends StatefulWidget {
  const UnravelShell({
    required this.controller,
    super.key,
  });

  final UnravelJournalController controller;

  @override
  State<UnravelShell> createState() => _UnravelShellState();
}

class _UnravelShellState extends State<UnravelShell> {
  int _selectedIndex = 0;
  StreamSubscription<String>? _notificationDeepLinkSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.notificationService.initialize());
    _notificationDeepLinkSubscription = widget
        .controller.notificationService.onCheckInThreadSelected
        .listen(_handleCheckInNotificationTap);
  }

  @override
  void dispose() {
    unawaited(_notificationDeepLinkSubscription?.cancel());
    super.dispose();
  }

  void _handleCheckInNotificationTap(String threadId) {
    if (!mounted) {
      return;
    }
    final OpenThreadRecord? target = widget.controller.findThreadById(threadId);
    setState(() => _selectedIndex = 0);
    unawaited(
      showUnravelKnotSheet(
        context: context,
        controller: widget.controller,
        initialMode: ReflectionSheetMode.afterMoment,
        initialThreadForCheckIn: target,
      ),
    );
  }

  void _openUnravelSheet() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ThreadWizardScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);

    return Scaffold(
      backgroundColor: ext.canvas,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: _selectedIndex == 0
                  ? HomeJournalScreen(
                      controller: widget.controller,
                      onNavigateToSanctuary: () =>
                          setState(() => _selectedIndex = 2),
                    )
                  : SanctuaryScreen(controller: widget.controller),
            ),

            // Floating "Hold to Unravel a Worry" Pill on Home Journal
            if (_selectedIndex == 0)
              Positioned(
                left: UnravelTheme.screenMargin,
                right: UnravelTheme.screenMargin,
                bottom: 16,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9999),
                      onTap: _openUnravelSheet,
                      onLongPress: _openUnravelSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: ext.groundingContainer,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: ext.border, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.spa_outlined,
                              size: 18,
                              color: ext.primaryAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Hold to Unravel a Worry',
                              style: typo.bodyMedium.copyWith(
                                color: ext.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: ext.primaryAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ext.canvas,
          border: Border(top: BorderSide(color: ext.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _BottomNavItem(
                  icon: Icons.menu_book_outlined,
                  label: 'Journal',
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _BottomNavItem(
                  icon: Icons.all_inclusive,
                  label: 'Unravel',
                  isSelected: false,
                  onTap: _openUnravelSheet,
                ),
                _BottomNavItem(
                  icon: Icons.spa_outlined,
                  label: 'Sanctuary',
                  isSelected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);
    final Color activeColor =
        isSelected ? ext.primaryAccent : ext.textMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 21, color: activeColor),
            const SizedBox(height: 3),
            Text(
              label,
              style: typo.metaMono.copyWith(
                color: activeColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
