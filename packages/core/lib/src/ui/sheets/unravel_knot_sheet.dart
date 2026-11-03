import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio/voice_capture_service.dart';
import '../../database/tables.dart';
import '../../database/unravel_database.dart';
import '../../theme/unravel_theme.dart';
import '../../theme/unravel_theme_extension.dart';
import '../../theme/unravel_typography.dart';
import '../state/unravel_journal_controller.dart';
import '../widgets/perspective_curve_painter.dart';

enum ReflectionSheetMode {
  beforeMoment,
  afterMoment,
}

/// Shows the "Unravel a Knot" reflection sheet.
///
/// Mandatory UI Polish Fix applied:
/// Renders a SINGLE clean header (`Unravel a Knot` + `№ 04` + ONE close `X` button)
/// and omits the redundant `Unravel Entry Modal` top bar from the Stitch mockup.
Future<void> showUnravelKnotSheet({
  required BuildContext context,
  required UnravelJournalController controller,
  ReflectionSheetMode initialMode = ReflectionSheetMode.beforeMoment,
  OpenThreadRecord? initialThreadForCheckIn,
  bool startVoice = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.unravelTheme.canvas,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: context.unravelTheme.border, width: 1),
    ),
    builder: (BuildContext sheetContext) {
      return UnravelKnotSheet(
        controller: controller,
        initialMode: initialMode,
        initialThreadForCheckIn: initialThreadForCheckIn,
        startVoice: startVoice,
      );
    },
  );
}

class UnravelKnotSheet extends StatefulWidget {
  const UnravelKnotSheet({
    required this.controller,
    this.initialMode = ReflectionSheetMode.beforeMoment,
    this.initialThreadForCheckIn,
    this.startVoice = false,
    super.key,
  });

  final UnravelJournalController controller;
  final ReflectionSheetMode initialMode;
  final OpenThreadRecord? initialThreadForCheckIn;
  final bool startVoice;

  @override
  State<UnravelKnotSheet> createState() => _UnravelKnotSheetState();
}

class _UnravelKnotSheetState extends State<UnravelKnotSheet> {
  late ReflectionSheetMode _mode;
  bool _isPlayingVoice = false;
  bool _gentleCheckInEnabled = true;
  int _predictedFear = 8;
  int _actualOutcome = 2;

  StreamSubscription<VoiceAmplitudeFrame>? _amplitudeSubscription;
  double _liveAmplitude = 0.08;
  double _voiceProgress = 0;
  String _timerLabel = '0:00 / 1:00';
  String _remainingLabel = '-1:00';
  List<double> _rollingAmplitudes = const <double>[];
  String _capturedTranscript = '';
  String _voiceNote =
      'Hold the journal pill, or press play, and speak. The wave follows your voice. Audio stays in memory only.';
  String? _saveError;

  late final TextEditingController _eventTitleController;
  late final TextEditingController _worryOneController;
  late final TextEditingController _worryTwoController;
  late final TextEditingController _groundingAnchorController;
  late final TextEditingController _afterNotesController;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _eventTitleController = TextEditingController();
    _worryOneController = TextEditingController();
    _worryTwoController = TextEditingController();
    _groundingAnchorController = TextEditingController();
    _afterNotesController = TextEditingController();
    _worryOneController.addListener(_refreshDraftCards);
    _worryTwoController.addListener(_refreshDraftCards);
    if (widget.startVoice &&
        widget.initialMode == ReflectionSheetMode.beforeMoment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isPlayingVoice) {
          unawaited(_toggleLiveVoiceCapture());
        }
      });
    }
    _amplitudeSubscription = widget
        .controller.voiceCaptureService.amplitudeStream
        .listen((VoiceAmplitudeFrame frame) {
      if (!mounted) {
        return;
      }
      setState(() {
        _liveAmplitude = frame.normalizedAmplitude;
        _voiceProgress = frame.progress;
        _timerLabel = frame.timerLabel;
        _remainingLabel = frame.remainingLabel;
        _rollingAmplitudes = frame.rollingSamples;
      });
    });
  }

  void _refreshDraftCards() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _worryOneController.removeListener(_refreshDraftCards);
    _worryTwoController.removeListener(_refreshDraftCards);
    unawaited(_amplitudeSubscription?.cancel());
    // Zero Persistent Audio Disk Leaks: immediately overwrite/unlink any
    // in-memory PCM or temp audio buffer when the sheet is dismissed.
    unawaited(widget.controller.voiceCaptureService.stopAndShred());
    _eventTitleController.dispose();
    _worryOneController.dispose();
    _worryTwoController.dispose();
    _groundingAnchorController.dispose();
    _afterNotesController.dispose();
    super.dispose();
  }

  Future<void> _toggleLiveVoiceCapture() async {
    if (_isPlayingVoice) {
      final EphemeralVoiceCaptureResult result =
          await widget.controller.voiceCaptureService.stopAndShred();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlayingVoice = false;
        _capturedTranscript = result.transcript;
      });
    } else {
      setState(() {
        _isPlayingVoice = true;
        _voiceNote = 'Listening… allow the microphone if Android asks.';
        _saveError = null;
      });
      try {
        await widget.controller.voiceCaptureService.startCapture();
        if (!mounted) {
          return;
        }
        setState(() {
          _voiceNote =
              'Listening. Speak the worry. Nothing is written to disk.';
        });
      } on PlatformException catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPlayingVoice = false;
          _voiceNote = error.code == 'PERMISSION_DENIED'
              ? 'Microphone is off. Allow it for Unravel, then press play.'
              : 'The microphone did not start. Press play to try again.';
        });
      }
    }
  }

  Future<void> _handleSaveBeforeMoment() async {
    if (widget.controller.voiceCaptureService.isRecording) {
      final EphemeralVoiceCaptureResult result =
          await widget.controller.voiceCaptureService.stopAndShred();
      _capturedTranscript = result.transcript;
    }

    final String title = _eventTitleController.text.trim().isEmpty
        ? 'Upcoming Moment'
        : _eventTitleController.text.trim();

    final List<UnraveledWorryItem> worries = <UnraveledWorryItem>[
      if (_worryOneController.text.trim().isNotEmpty)
        UnraveledWorryItem(
          indexNumber: '01',
          worryText: _worryOneController.text.trim(),
          controlScope: WorryControlScope.withinMyControl,
          actionOrGrounding: 'A step that belongs to your craft.',
        ),
      if (_worryTwoController.text.trim().isNotEmpty)
        UnraveledWorryItem(
          indexNumber: '02',
          worryText: _worryTwoController.text.trim(),
          controlScope: WorryControlScope.beyondMyControl,
          actionOrGrounding: 'This part belongs to fortune, not to your craft.',
        ),
    ];

    try {
      await widget.controller.createOpenThread(
        eventTitle: title,
        worries: worries,
        groundingAnchor: _groundingAnchorController.text.trim(),
        predictedFear: _predictedFear,
        eventOccursAt: DateTime.now().add(const Duration(hours: 18)),
        scheduleNotification: _gentleCheckInEnabled,
        voiceTranscript: _capturedTranscript,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saveError = 'This thread could not be kept. Try Save again.';
        });
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSaveAfterMoment() async {
    final OpenThreadRecord? target = widget.initialThreadForCheckIn ??
        (widget.controller.activeOpenThreads.isNotEmpty
            ? widget.controller.activeOpenThreads.first
            : null);
    if (target == null) {
      if (mounted) {
        setState(() {
          _saveError = 'This moment is not on this device.';
        });
      }
      return;
    }

    try {
      await widget.controller.completeAfterMomentCheckIn(
        threadId: target.id,
        actualOutcome: _actualOutcome,
        reflectionNotes: _afterNotesController.text.trim(),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saveError = 'This check-in could not be kept. Try again.';
        });
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);
    final int entryNumber = widget.controller.activeOpenThreads.length +
        widget.controller.perspectiveEntries.length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.65,
      maxChildSize: 0.96,
      builder: (BuildContext context, ScrollController scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            UnravelTheme.screenMargin,
            20,
            UnravelTheme.screenMargin,
            32,
          ),
          children: <Widget>[
            // 1. Single Clean Header (No redundant top modal bar or double close buttons)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          'Unravel a Knot',
                          style: typo.displaySerif.copyWith(fontSize: 28),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '№ ${entryNumber.toString().padLeft(2, '0')}',
                        style: typo.metaMono,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss reflection',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: ext.card,
                    side: BorderSide(color: ext.border, width: 1),
                  ),
                  icon: Icon(Icons.close, size: 18, color: ext.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Segmented Pill Toggle ("Before a Moment" vs "After a Moment")
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: ext.card,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: ext.border, width: 1),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _ModeTabButton(
                      title: 'Before a Moment',
                      subtitle: '(Untangle Worries)',
                      isSelected: _mode == ReflectionSheetMode.beforeMoment,
                      onTap: () => setState(
                        () => _mode = ReflectionSheetMode.beforeMoment,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ModeTabButton(
                      title: 'After a Moment',
                      subtitle: '(How It Unfolded)',
                      isSelected: _mode == ReflectionSheetMode.afterMoment,
                      onTap: () => setState(
                        () => _mode = ReflectionSheetMode.afterMoment,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_mode == ReflectionSheetMode.beforeMoment)
              ..._buildBeforeMomentBody(ext, typo)
            else
              ..._buildAfterMomentBody(ext, typo),
          ],
        );
      },
    );
  }

  List<Widget> _buildBeforeMomentBody(
    UnravelThemeExtension ext,
    UnravelTypography typo,
  ) {
    return <Widget>[
      // Organic Voice Capture Card
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
                      Icons.graphic_eq,
                      size: 16,
                      color: ext.primaryAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'VOICE REFLECTION',
                      style: typo.metaMono.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  _timerLabel,
                  style: typo.audioTimerMono.copyWith(
                    color: ext.secondaryAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OrganicVoiceWaveform(
              progress: _voiceProgress,
              amplitude: _liveAmplitude,
              rollingSamples: _rollingAmplitudes,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                InkWell(
                  borderRadius: BorderRadius.circular(9999),
                  onTap: _toggleLiveVoiceCapture,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ext.primaryAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlayingVoice ? Icons.pause : Icons.play_arrow,
                      size: 18,
                      color: ext.onPrimaryAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9999),
                    child: LinearProgressIndicator(
                      value: _voiceProgress,
                      minHeight: 6,
                      backgroundColor: ext.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ext.primaryAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(_remainingLabel, style: typo.metaMono),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ext.canvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ext.border, width: 1),
              ),
              child: Text(
                _isPlayingVoice
                    ? _voiceNote
                    : (_capturedTranscript.trim().isEmpty
                        ? _voiceNote
                        : '“$_capturedTranscript”'),
                style: typo.transcriptSerifItalic,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: ext.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'On-device transcript · Raw audio never uploaded',
                      style: typo.metaMono,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Upcoming Event Title & Fear Intensity
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ext.card,
          borderRadius: BorderRadius.circular(UnravelTheme.cardRadius),
          border: Border.all(color: ext.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('UPCOMING MOMENT', style: typo.metaMono),
            const SizedBox(height: 6),
            TextField(
              controller: _eventTitleController,
              style: typo.eventTitleSerif,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Name the upcoming event...',
                hintStyle: typo.eventTitleSerif.copyWith(color: ext.textMuted),
              ),
            ),
            Divider(color: ext.border, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('WHAT MY FEAR PREDICTS', style: typo.metaMono),
                Text(
                  '$_predictedFear / 10',
                  style: typo.worryIndexMono.copyWith(
                    color: ext.terracottaAccent,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: ext.terracottaAccent,
                inactiveTrackColor: ext.border,
                thumbColor: ext.terracottaAccent,
              ),
              child: Slider(
                value: _predictedFear.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (double value) {
                  setState(() => _predictedFear = value.round());
                },
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Untangled Perspective (Dual Lens)
      Row(
        children: <Widget>[
          Icon(Icons.all_inclusive, size: 16, color: ext.textMuted),
          const SizedBox(width: 6),
          Text('UNTANGLED PERSPECTIVE', style: typo.metaMono),
        ],
      ),
      const SizedBox(height: 10),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ext.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ext.secondaryAccent, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'WHAT FEAR SAYS',
                          style: typo.metaMono.copyWith(
                            color: ext.secondaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _worryOneController.text.trim().isEmpty
                              ? 'Write the fear in the first worry below.'
                              : '“${_worryOneController.text.trim()}”',
                          style: typo.transcriptSerifItalic.copyWith(
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ext.secondaryAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: ext.secondaryAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Anxiety Projection',
                        style: typo.metaMono.copyWith(
                          fontSize: 10,
                          color: ext.secondaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ext.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ext.primaryAccent, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'GROUNDED TRUTH',
                          style: typo.metaMono.copyWith(
                            color: ext.primaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _worryTwoController.text.trim().isEmpty
                              ? 'Write what sits outside your control in the second worry.'
                              : _worryTwoController.text.trim(),
                          style: typo.bodyMedium.copyWith(
                            color: ext.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ext.primaryAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: ext.primaryAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Calibrated Reality',
                        style: typo.metaMono.copyWith(
                          fontSize: 10,
                          color: ext.primaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Numbered Worries (01 WITHIN MY CONTROL, 02 BEYOND MY CONTROL)
      _EditableWorryCard(
        indexLabel: '01',
        scope: WorryControlScope.withinMyControl,
        controller: _worryOneController,
        hintText: 'A worry you can act on',
        subnote: 'A step that belongs to your craft.',
      ),
      const SizedBox(height: 10),
      _EditableWorryCard(
        indexLabel: '02',
        scope: WorryControlScope.beyondMyControl,
        controller: _worryTwoController,
        hintText: 'A worry that belongs to fortune',
        subnote: 'You cannot steer this part. Name it, then set it down.',
      ),
      const SizedBox(height: 20),

      // Physical Grounding Anchor Box
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ext.groundingContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ext.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.spa_outlined, size: 16, color: ext.primaryAccent),
                const SizedBox(width: 6),
                Text(
                  'PHYSICAL ANCHOR',
                  style: typo.metaMono.copyWith(
                    color: ext.primaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _groundingAnchorController,
              maxLines: 2,
              style: typo.bodyMedium.copyWith(color: ext.textPrimary),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'A physical action you can take in the room',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Gentle Post-Event Check-In Toggle
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ext.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ext.border, width: 1),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Gentle Post-Event Check-In',
                    style: typo.settingTitleSans.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Notify me 1 hour after the event to record how reality actually unfolded.',
                    style: typo.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: _gentleCheckInEnabled,
              activeThumbColor: ext.onPrimaryAccent,
              activeTrackColor: ext.primaryAccent,
              onChanged: (bool value) =>
                  setState(() => _gentleCheckInEnabled = value),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      if (_saveError != null) ...<Widget>[
        Text(
          _saveError!,
          textAlign: TextAlign.center,
          style: typo.bodyMedium.copyWith(color: ext.terracottaAccent),
        ),
        const SizedBox(height: 10),
      ],

      // Primary Pill CTA
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _handleSaveBeforeMoment,
          icon: const Text('Save to Open Threads'),
          label: const Icon(Icons.arrow_forward, size: 18),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'You are preparing your mind, not predicting catastrophe.',
        textAlign: TextAlign.center,
        style: typo.metaMono,
      ),
    ];
  }

  List<Widget> _buildAfterMomentBody(
    UnravelThemeExtension ext,
    UnravelTypography typo,
  ) {
    final OpenThreadRecord? target = widget.initialThreadForCheckIn ??
        (widget.controller.activeOpenThreads.isNotEmpty
            ? widget.controller.activeOpenThreads.first
            : null);
    final int initialFear = target?.predictedFear ?? _predictedFear;

    return <Widget>[
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
            Text('AFTER A MOMENT · REALITY CHECK-IN', style: typo.metaMono),
            const SizedBox(height: 6),
            Text(
              target?.eventTitle ?? 'This moment is not on this device.',
              style: typo.eventTitleSerif,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('WHAT FEAR PREDICTED', style: typo.metaMono),
                Text(
                  '$initialFear / 10',
                  style: typo.worryIndexMono.copyWith(
                    color: ext.terracottaAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('HOW LIFE ACTUALLY UNFOLDED', style: typo.metaMono),
                Text(
                  '$_actualOutcome / 10',
                  style: typo.worryIndexMono.copyWith(
                    color: ext.primaryAccent,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: ext.primaryAccent,
                inactiveTrackColor: ext.border,
                thumbColor: ext.primaryAccent,
              ),
              child: Slider(
                value: _actualOutcome.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (double value) {
                  setState(() => _actualOutcome = value.round());
                },
              ),
            ),
            const SizedBox(height: 12),
            Text('ENCRYPTED POST-EVENT REFLECTION', style: typo.metaMono),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ext.canvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ext.border, width: 1),
              ),
              child: TextField(
                controller: _afterNotesController,
                maxLines: 3,
                style: typo.bodyLarge,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'How did the moment actually unfold?',
                  hintStyle: typo.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AES-256-GCM encrypted on-device before saving to PerspectiveLogs.',
              style: typo.metaMono,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _handleSaveAfterMoment,
          icon: const Text('Record to Perspective Curve'),
          label: const Icon(Icons.check, size: 18),
        ),
      ),
    ];
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? ext.primaryAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: typo.pillButton.copyWith(
                fontSize: 13,
                color: isSelected ? ext.onPrimaryAccent : ext.textMuted,
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: typo.metaMono.copyWith(
                fontSize: 10,
                color: isSelected
                    ? ext.onPrimaryAccent.withValues(alpha: 0.85)
                    : ext.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableWorryCard extends StatelessWidget {
  const _EditableWorryCard({
    required this.indexLabel,
    required this.scope,
    required this.controller,
    required this.subnote,
    this.hintText,
  });

  final String indexLabel;
  final WorryControlScope scope;
  final TextEditingController controller;
  final String subnote;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);
    final bool isWithin = scope == WorryControlScope.withinMyControl;
    final Color badgeColor = isWithin ? ext.primaryAccent : ext.secondaryAccent;

    return Container(
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
              Text(
                indexLabel,
                style: typo.worryIndexMono.copyWith(color: badgeColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  scope.badgeLabel,
                  style: typo.metaMono.copyWith(
                    fontSize: 10,
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: 2,
            style: typo.bodyLarge.copyWith(fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: typo.bodyLarge.copyWith(
                fontSize: 15,
                color: ext.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(subnote, style: typo.bodyMedium.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
