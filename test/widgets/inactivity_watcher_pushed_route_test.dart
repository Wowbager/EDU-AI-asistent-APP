import 'package:drift/native.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/session_meta.dart';
import 'package:eduai/core/widgets/inactivity_watcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// InactivityWatcher lives inside the root route, but Můj účet, Doplňky and the
/// lesson/course detail pages are imperative `Navigator.push`es — sibling
/// overlay entries *above* that route. A subtree `Listener` never hit-tests
/// them, so working in those pages looked like idling and the shared-device
/// session was logged out mid-use (BR-CMB8RU). Activity has to be observed at
/// the binding, not in the widget subtree.
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late SessionMeta session;

  /// Comfortably past the 10s write throttle in [SessionMeta.touchActivity],
  /// and well short of the 15-minute idle limit.
  final stale = DateTime.now().subtract(const Duration(minutes: 5));

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'session_shared_device': true,
      'session_last_active_at': stale.millisecondsSinceEpoch,
    });
    prefs = await SharedPreferences.getInstance();
    session = SessionMeta(prefs);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sessionMetaProvider.overrideWithValue(session),
        ],
        child: MaterialApp(
          home: InactivityWatcher(
            onLogout: () async {},
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const _DetailPage()),
                    ),
                    child: const Text('root'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Unmount so the watcher's periodic timers are cancelled — flutter_test
  /// refuses to end a test with them still pending.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  /// Rewind the idle clock so only the *next* event can move it forward.
  Future<void> rewindIdleClock() async {
    await prefs.setInt('session_last_active_at', stale.millisecondsSinceEpoch);
  }

  testWidgets('a tap on the root route resets the idle clock', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();

    expect(session.lastActiveAt!.isAfter(stale), isTrue);

    await disposeApp(tester);
  });

  testWidgets('a tap on a pushed route resets the idle clock', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);

    // The tap that opened the route counted as activity; only the tap *inside*
    // the pushed page should be able to move the clock from here.
    await rewindIdleClock();

    await tester.tap(find.text('detail'));
    await tester.pump();

    expect(session.lastActiveAt!.isAfter(stale), isTrue);

    await disposeApp(tester);
  });

  testWidgets('a scroll on a pushed route resets the idle clock', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();
    await rewindIdleClock();

    // Scroll wheel arrives as a pointer *signal*, not a move — reading a long
    // page must not count as idling.
    final scrollable = find.byType(Scrollable).last;
    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(session.lastActiveAt!.isAfter(stale), isTrue);

    await disposeApp(tester);
  });
}

class _DetailPage extends StatelessWidget {
  const _DetailPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const SizedBox(height: 400),
          ElevatedButton(onPressed: () {}, child: const Text('detail')),
          const SizedBox(height: 1200),
        ],
      ),
    );
  }
}
