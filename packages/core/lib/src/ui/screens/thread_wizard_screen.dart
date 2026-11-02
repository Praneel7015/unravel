import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio/voice_capture_service.dart';
import '../../crypto/envelope_encryption_service.dart';
import '../../database/tables.dart';
import '../../journal/journal_field_rules.dart';
import '../../theme/unravel_theme.dart';
import '../../theme/unravel_theme_extension.dart';
import '../../theme/unravel_typography.dart';
import '../state/unravel_journal_controller.dart';
import '../widgets/perspective_curve_painter.dart';

/// Full-screen sequence that saves one open thread only when every field is valid.
class ThreadWizardScreen extends StatefulWidget {
  const ThreadWizardScreen({
    required this.controller,
    super.key,
  });

  final UnravelJournalController controller;

  @override
  State<ThreadWizardScreen> createState() => _ThreadWizardScreenState();
}

class _ThreadWizardScreenState extends State<ThreadWizardScreen> {
  static const List<String> _titles = <String>[
    'Name the moment',
    'When it happens',
    'The worry',
    'A physical anchor',
    'What fear predicts',
  ];

  int _step = 0;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _worry = TextEditingController();
  final TextEditingController _anchor = TextEditingController();
  DateTime? _when;
  WorryControlScope _scope = WorryControlScope.withinMyControl;
  int _fear = 5;
  String? _error;
  String? _transcript;
  bool _listening = false;
  bool _saving = false;
  double _amplitude = 0.0;
  List<double> _samples = const <double>[];

  @override
  void dispose() {
    _title.dispose();
    _worry.dispose();
    _anchor.dispose();
    if (widget.controller.voiceCaptureService.isRecording) {
      widget.controller.voiceCaptureService.stopAndShred();
    }
    super.dispose();
  }

  bool _validateCurrentStep() {
    String? error;
    switch (_step) {
      case 0:
        error = JournalFieldRules.titleError(_title.text);
      case 1:
        error = _when == null ? 'Choose the date and the time.' : null;
      case 2:
        error = JournalFieldRules.worryError(_worry.text);
      case 3:
        error = JournalFieldRules.anchorError(_anchor.text);
      case 4:
        error = JournalFieldRules.fearError(_fear);
    }
    setState(() => _error = error);
    return error == null;
  }

  Future<void> _pickWhen() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _when ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when ?? now),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _error = null;
    });
  }

  Future<void> _toggleVoice() async {
    final VoiceCaptureService voice = widget.controller.voiceCaptureService;
    if (_listening) {
      final EphemeralVoiceCaptureResult result = await voice.stopAndShred();
      if (!mounted) {
        return;
      }
      setState(() {
        _listening = false;
        _amplitude = 0;
        _samples = const <double>[];
        final String spoken = result.transcript.trim();
        _transcript = spoken.isEmpty ? _transcript : spoken;
        if (spoken.isNotEmpty) {
          final String written = _worry.text.trim();
          _worry.text = written.isEmpty ? spoken : '$written\n$spoken';
        }
      });
      return;
    }
    setState(() => _error = null);
    try {
      await voice.startCapture();
      voice.amplitudeStream.listen((VoiceAmplitudeFrame frame) {
        if (mounted && _listening) {
          setState(() {
            _amplitude = frame.normalizedAmplitude;
            _samples = frame.rollingSamples;
          });
        }
      });
      if (mounted) {
        setState(() => _listening = true);
      }
    } on PlatformException {
      if (mounted) {
        setState(() {
          _error = 'The microphone is off. You can type the worry instead.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_validateCurrentStep()) {
      return;
    }
    if (_listening) {
      await _toggleVoice();
    }
    setState(() => _saving = true);
    try {
      await widget.controller.createOpenThread(
        eventTitle: _title.text,
        worries: <UnraveledWorryItem>[
          UnraveledWorryItem(
            indexNumber: '01',
            worryText: _worry.text,
            controlScope: _scope,
            actionOrGrounding: _anchor.text.trim(),
          ),
        ],
        groundingAnchor: _anchor.text,
        predictedFear: _fear,
        eventOccursAt: _when!,
        voiceTranscript: _transcript,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message?.toString() ?? 'Check the fields and save again.';
        });
      }
    } on UnravelCryptoException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message.contains('16384')
              ? 'That spoken note is too long to keep. Shorten it and save again.'
              : error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error
              .toString()
              .replaceFirst(RegExp(r'^[A-Za-z][A-Za-z .]*: '), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);
    return Scaffold(
      backgroundColor: ext.canvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            UnravelTheme.screenMargin,
            12,
            UnravelTheme.screenMargin,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${_step + 1} / ${_titles.length}',
                      style: typo.metaMono,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss reflection',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: ext.textPrimary),
                  ),
                ],
              ),
              Text(_titles[_step], style: typo.displaySerif),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: _stepBody(ext, typo),
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: typo.bodyMedium.copyWith(color: ext.terracottaAccent),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  if (_step > 0)
                    TextButton(
                      onPressed: _saving ? null : () => setState(() => _step -= 1),
                      child: Text('Back', style: typo.bodyMedium),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () {
                            if (_step < _titles.length - 1) {
                              if (_validateCurrentStep()) {
                                setState(() => _step += 1);
                              }
                            } else {
                              _save();
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: ext.primaryAccent,
                      foregroundColor: ext.onPrimaryAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    ),
                    child: Text(
                      _step == _titles.length - 1 ? 'Save to Open Threads' : 'Continue',
                      style: typo.pillButton,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody(UnravelThemeExtension ext, UnravelTypography typo) {
    switch (_step) {
      case 0:
        return TextField(
          controller: _title,
          maxLength: JournalFieldRules.titleMax,
          style: typo.eventTitleSerif,
          decoration: const InputDecoration(
            hintText: 'The conversation, the exam, the trip',
            counterText: '',
          ),
        );
      case 1:
        final DateTime? when = _when;
        final String label = when == null
            ? 'Choose a date and time'
            : '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}  ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
        return Align(
          alignment: Alignment.topLeft,
          child: OutlinedButton(
            onPressed: _pickWhen,
            child: Text(label, style: typo.bodyLarge),
          ),
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _worry,
              minLines: 3,
              maxLines: 6,
              style: typo.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'What are you afraid will happen?',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Within my control'),
                  selected: _scope == WorryControlScope.withinMyControl,
                  onSelected: (_) => setState(
                    () => _scope = WorryControlScope.withinMyControl,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Beyond my control'),
                  selected: _scope == WorryControlScope.beyondMyControl,
                  onSelected: (_) => setState(
                    () => _scope = WorryControlScope.beyondMyControl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OrganicVoiceWaveform(
              progress: 0,
              amplitude: _amplitude,
              rollingSamples: _samples,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _toggleVoice,
              child: Text(_listening ? 'Stop speaking' : 'Speak instead', style: typo.bodyMedium),
            ),
          ],
        );
      case 3:
        return TextField(
          controller: _anchor,
          maxLength: JournalFieldRules.anchorMax,
          minLines: 3,
          maxLines: 6,
          style: typo.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'A step, a breath, or a sentence you can return to',
            counterText: '',
          ),
        );
      default:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (int value = 1; value <= 10; value++)
              ChoiceChip(
                label: Text(value.toString(), style: typo.worryIndexMono),
                selected: _fear == value,
                onSelected: (_) => setState(() => _fear = value),
              ),
          ],
        );
    }
  }
}
