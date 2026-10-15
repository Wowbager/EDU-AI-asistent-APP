// Throwaway local entrypoint to eyeball the first-login onboarding without a
// real account: `flutter run -t lib/dev_onboarding_preview.dart`. Not part of
// the app; delete freely.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/app_database.dart';
import 'core/providers/core_providers.dart';
import 'core/services/auth_token_storage.dart';
import 'core/theme/app_theme.dart';
import 'pages/profile_setup_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final authTokenStorage = AuthTokenStorage(prefs: prefs);
  await authTokenStorage.load();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authTokenStorageProvider.overrideWithValue(authTokenStorage),
      ],
      child: const _PreviewApp(),
    ),
  );
}

class _PreviewApp extends ConsumerWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.light,
      home: FutureBuilder<void>(
        future: _seed(ref),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return ProfileSetupPage(
            email: 'demo@example.com',
            onComplete: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('onboarding complete')),
            ),
          );
        },
      ),
    );
  }

  Future<void> _seed(WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final existing = await db.getActiveUser();
    if (existing == null) {
      await db.createAndActivateUser(
        UsersTableCompanion(
          id: const Value('preview-user'),
          email: const Value('demo@example.com'),
          name: const Value('Krtek'),
          isEmailValidated: const Value(true),
          isActive: const Value(true),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}
