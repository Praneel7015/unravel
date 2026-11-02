import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../journal/journal_field_rules.dart';
import '../../theme/unravel_theme_extension.dart';
import '../../theme/unravel_typography.dart';
import '../state/unravel_journal_controller.dart';

/// First-run sequence: what Unravel is, a passphrase, the microphone, and check-ins.
class SetupFlow extends StatefulWidget {
  const SetupFlow({
    required this.controller,
    super.key,
  });

  final UnravelJournalController controller;

  @override
  State<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends State<SetupFlow> {
  late int _step;
  final TextEditingController _passphrase = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _step = widget.controller.hasWrappedKey ? 2 : 0;
  }

  @override
  void dispose() {
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _savePassphrase() async {
    final String? error = JournalFieldRules.passphraseError(
      _passphrase.text,
      _confirm.text,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.savePassphrase(_passphrase.text);
      if (mounted) {
        setState(() {
          _busy = false;
          _step = 2;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'The passphrase could not be saved. Try again.';
        });
      }
    }
  }

  Future<void> _allowMicrophone() async {
    setState(() => _busy = true);
    try {
      await widget.controller.voiceCaptureService.startCapture(
        maxDuration: const Duration(seconds: 2),
      );
      await widget.controller.voiceCaptureService.stopAndShred();
    } on PlatformException {
      // The person can keep going. The wizard explains the microphone again.
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _step = 3;
        });
      }
    }
  }

  Future<void> _allowNotifications() async {
    setState(() => _busy = true);
    await widget.controller.notificationService.requestCheckInPermission();
    if (mounted) {
      setState(() => _busy = false);
    }
    await widget.controller.markSetupFinished();
  }

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);
    return Scaffold(
      backgroundColor: ext.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${_step + 1} / 4',
                style: typo.metaMono,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: _body(ext, typo),
                ),
              ),
              if (_error != null) ...<Widget>[
                Text(_error!, style: typo.bodyMedium.copyWith(color: ext.terracottaAccent)),
                const SizedBox(height: 12),
              ],
              _actions(ext, typo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(UnravelThemeExtension ext, UnravelTypography typo) {
    switch (_step) {
      case 0:
        return _copy(
          typo,
          'Welcome to Unravel',
          'A journal for a single upcoming moment, before it happens and after it has passed.',
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('A passphrase for this journal', style: typo.displaySerif),
            const SizedBox(height: 12),
            Text(
              'It wraps the key that locks your reflections. Unravel cannot recover it.',
              style: typo.bodyLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passphrase,
              obscureText: true,
              style: typo.bodyLarge,
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              style: typo.bodyLarge,
              decoration: const InputDecoration(labelText: 'Type it again'),
            ),
          ],
        );
      case 2:
        return _copy(
          typo,
          'The microphone stays on the phone',
          'Speaking a worry is optional. Unravel asks the system for the microphone only after this screen, and it does not keep the recording.',
        );
      default:
        return _copy(
          typo,
          'A quiet check-in after the moment',
          'If you allow notifications, Unravel can ask once, an hour after the moment, how it went. It will not remind you again about the same thread.',
        );
    }
  }

  Widget _copy(UnravelTypography typo, String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: typo.displaySerif),
        const SizedBox(height: 16),
        Text(body, style: typo.bodyLarge),
      ],
    );
  }

  Widget _actions(UnravelThemeExtension ext, UnravelTypography typo) {
    if (_step == 1) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _busy ? null : _savePassphrase,
          style: FilledButton.styleFrom(
            backgroundColor: ext.primaryAccent,
            foregroundColor: ext.onPrimaryAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text('Keep this passphrase', style: typo.pillButton),
        ),
      );
    }
    final bool optional = _step >= 2;
    return Row(
      children: <Widget>[
        if (optional)
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    if (_step == 2) {
                      setState(() => _step = 3);
                    } else {
                      widget.controller.markSetupFinished();
                    }
                  },
            child: Text('Not now', style: typo.bodyMedium),
          ),
        const Spacer(),
        FilledButton(
          onPressed: _busy
              ? null
              : () {
                  if (_step == 0) {
                    setState(() => _step = 1);
                  } else if (_step == 2) {
                    _allowMicrophone();
                  } else {
                    _allowNotifications();
                  }
                },
          style: FilledButton.styleFrom(
            backgroundColor: ext.primaryAccent,
            foregroundColor: ext.onPrimaryAccent,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          child: Text(_step == 0 ? 'Continue' : 'Allow', style: typo.pillButton),
        ),
      ],
    );
  }
}

/// Asks for the existing passphrase before the journal opens.
class UnlockJournalScreen extends StatefulWidget {
  const UnlockJournalScreen({
    required this.controller,
    super.key,
  });

  final UnravelJournalController controller;

  @override
  State<UnlockJournalScreen> createState() => _UnlockJournalScreenState();
}

class _UnlockJournalScreenState extends State<UnlockJournalScreen> {
  final TextEditingController _passphrase = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final bool opened = await widget.controller.unlock(_passphrase.text);
    if (!opened && mounted) {
      setState(() {
        _busy = false;
        _error = 'That passphrase does not open this journal.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);
    return Scaffold(
      backgroundColor: ext.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Open your journal', style: typo.displaySerif),
              const SizedBox(height: 12),
              Text(
                'The reflections stay on this phone until the passphrase unwraps them.',
                style: typo.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passphrase,
                obscureText: true,
                style: typo.bodyLarge,
                decoration: const InputDecoration(labelText: 'Passphrase'),
                onSubmitted: (_) => _unlock(),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: typo.bodyMedium.copyWith(color: ext.terracottaAccent),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _unlock,
                  style: FilledButton.styleFrom(
                    backgroundColor: ext.primaryAccent,
                    foregroundColor: ext.onPrimaryAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Open', style: typo.pillButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
