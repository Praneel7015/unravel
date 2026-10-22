import 'package:flutter/material.dart';
import 'package:unravel_core/unravel_core.dart';
import 'package:unravel_sync_store/unravel_sync_store.dart';

/// Compile-time environment variables injected strictly via `--dart-define`.
const String _kCloudUrl = String.fromEnvironment('CLOUD_URL');
const String _kSupabasePublishableKey =
    String.fromEnvironment('SB_PUBLISHABLE_KEY');

/// Entrypoint for `app.unravel.store` (App Store & Play Store Edition).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UnravelTypography.enforceAirGappedFonts();

  const StoreCloudConfig cloudConfig = StoreCloudConfig(
    cloudUrl: _kCloudUrl,
    supabasePublishableKey: _kSupabasePublishableKey,
  );

  final UnravelSyncEngine syncEngine = StoreSyncEngine(
    config: cloudConfig,
    tier: UnravelEntitlementTier.freeOrFossLocal,
  );

  runApp(
    UnravelApp(
      syncEngine: syncEngine,
      isFossBuild: false,
    ),
  );
}
