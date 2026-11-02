import 'package:flutter/material.dart';

import '../../theme/unravel_theme.dart';
import '../../theme/unravel_theme_extension.dart';
import '../../theme/unravel_typography.dart';

/// The same privacy and security text the website shows, kept in the app
/// so it can be read with no network.
class LegalNoticeScreen extends StatelessWidget {
  const LegalNoticeScreen({
    required this.title,
    required this.paragraphs,
    super.key,
  });

  final String title;
  final List<String> paragraphs;

  static const List<String> privacy = <String>[
    'The open-source app keeps the journal on the phone. A moment, a worry, and the note you write after it are stored on this device.',
    'The passphrase wraps the key that locks those words. Unravel cannot recover a forgotten passphrase, and the passphrase never leaves the phone.',
    'A spoken worry is turned into words on the phone. The recording is wiped when you stop. Unravel does not keep the audio.',
    'An export from the store app cannot be opened by the open-source app. An export from the open-source app can be opened by the store app, and by another open-source install, when the passphrase matches.',
    'A model address, a key you type, and a self-host address stay on the phone. These fields do not create a cloud account.',
  ];

  static const List<String> security = <String>[
    'Reflections are encrypted on the phone with AES-256-GCM before they are written. The key is wrapped with Argon2id and the passphrase you choose.',
    'The recording of a spoken worry is held in memory only long enough to write the words. Every byte of that audio is then cleared.',
    'A journal file is encrypted with the same key. The wrong passphrase writes nothing. A file marked by the store app is refused by the open-source app before it is decrypted.',
    'A WebDAV password, a model address, and a cloud account are not written into the journal file.',
  ];

  @override
  Widget build(BuildContext context) {
    final UnravelThemeExtension ext = context.unravelTheme;
    final UnravelTypography typo = UnravelTypography.fromExtension(ext);
    return Scaffold(
      backgroundColor: ext.canvas,
      appBar: AppBar(
        backgroundColor: ext.canvas,
        foregroundColor: ext.textPrimary,
        elevation: 0,
        title: Text(title, style: typo.eventTitleSerif),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            UnravelTheme.screenMargin,
            8,
            UnravelTheme.screenMargin,
            32,
          ),
          children: <Widget>[
            for (final String paragraph in paragraphs) ...<Widget>[
              Text(paragraph, style: typo.bodyLarge),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
