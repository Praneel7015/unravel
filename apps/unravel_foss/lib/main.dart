import 'package:flutter/material.dart';
import 'package:unravel_core/unravel_core.dart';
import 'package:unravel_sync_foss/unravel_sync_foss.dart';

/// Empty until a host exists. Set `PUBLIC_SITE_ORIGIN` at build time when you have one.
const String kPublicSiteOrigin = String.fromEnvironment('PUBLIC_SITE_ORIGIN');

/// Entrypoint for `app.unravel.foss` (F-Droid / Libre Edition).
/// Contains ZERO proprietary dependencies, commercial cloud URLs, or API keys.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final UnravelSyncEngine syncEngine = FossSyncEngine();
  runApp(
    UnravelApp(
      syncEngine: syncEngine,
      isFossBuild: true,
      publicSiteOrigin: kPublicSiteOrigin,
    ),
  );
}
