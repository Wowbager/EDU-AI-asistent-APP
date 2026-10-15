// BR-TT6TD7: joining a class by the four-character class code a teacher set
// on it — from the Upravit profil dialog and from a /join/:code link.
//
// The API tells a class code from a student code by length and answers both
// on the same lookup/join endpoints, so what is pinned here is the app side:
// the dialog opens on four boxes (with a switch to the six-box student code),
// and a parked /join code waits for an account that can use it, sends a guest
// to log in without losing the code, and shows every refusal — "Už jsi ve
// třídě X." above all — as a snackbar, since a link has no input to show it
// under.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/connectivity/connectivity_service.dart';
import 'package:eduai/core/consent/minor_mode.dart';
import 'package:eduai/core/database/app_database.dart';
import 'package:eduai/core/network/api_client.dart';
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/services/classroom_join_service.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/util/classroom_join_flow.dart';
import 'package:eduai/routing/deep_link.dart';

class _Conn implements ConnectivityService {
  @override
  Future<bool> get isOnline async => true;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Answers lookup/join from a script and records the codes it was sent.
class _FakeJoin implements ClassroomJoinService {
  final ApiResult<ClassroomLookup> lookupResult;
  final List<String> lookups = [];
  final List<String> joins = [];

  _FakeJoin(this.lookupResult);

  static const _classroom = ClassroomSummary(id: 7, name: '5.A');

  factory _FakeJoin.found() => _FakeJoin(
        ApiResult.success(const ClassroomLookup(classroom: _classroom)),
      );

  @override
  Future<ApiResult<ClassroomLookup>> lookup(String code) async {
    lookups.add(code);
    return lookupResult;
  }

  @override
  Future<ApiResult<ClassroomJoined>> join(String code) async {
    joins.add(code);
    return ApiResult.success(const ClassroomJoined(
      classroom: _classroom,
      classrooms: [_classroom],
    ));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Minor extends MinorModeNotifier {
  _Minor() {
    state = true;
  }
}

UsersTableData _user({required bool guest}) {
  final now = DateTime(2026, 1, 1);
  return UsersTableData(
    id: 'u1',
    email: guest ? '' : 'jana@example.com',
    name: 'Jana',
    avatarIndex: 0,
    selectedSubjects: '[0]',
    isEmailValidated: !guest,
    isActive: true,
    syncStatus: 0,
    createdAt: now,
    updatedAt: now,
  );
}

/// Mounts a button that runs [action] with a real context/ref, under the
/// given account state. [user] null = the local user row is still loading.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _FakeJoin join,
  required Future<void> Function(BuildContext, WidgetRef) action,
  Stream<UsersTableData?>? user,
  bool minor = false,
  String? parkedCode,
}) async {
  final container = ProviderContainer(overrides: [
    classroomJoinServiceProvider.overrideWithValue(join),
    connectivityServiceProvider.overrideWithValue(_Conn()),
    activeUserStreamProvider.overrideWith(
      (ref) => user ?? Stream.value(_user(guest: false)),
    ),
    minorModeProvider.overrideWith((ref) => minor ? _Minor() : MinorModeNotifier()),
  ]);
  addTearDown(container.dispose);
  container.read(pendingClassroomJoinCodeProvider.notifier).state = parkedCode;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: ElevatedButton(
                onPressed: () => action(context, ref),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // Let the user stream deliver its row.
  container.read(activeUserStreamProvider);
  await tester.pump();
  await tester.pump();
  return container;
}

Future<void> _go(WidgetTester tester) async {
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

/// The code dialog keeps its "Hledám třídu…" spinner running under the
/// confirmation dialog, so pumpAndSettle would never return; pump a bounded
/// number of frames instead.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('Upravit profil code dialog', () {
    Future<void> openDialog(WidgetTester tester, _FakeJoin join) async {
      await _pump(
        tester,
        join: join,
        action: (context, ref) => showClassroomCodeDialog(context, ref),
      );
      await _go(tester);
    }

    testWidgets('opens on four boxes for the class code', (tester) async {
      await openDialog(tester, _FakeJoin.found());

      expect(find.text(AppStrings.classroomJoinClassCodeHint), findsOneWidget);
      expect(find.byKey(const ValueKey('code_box_3')), findsOneWidget);
      expect(find.byKey(const ValueKey('code_box_4')), findsNothing);
    });

    testWidgets('a four-character code asks, then joins', (tester) async {
      final join = _FakeJoin.found();
      await openDialog(tester, join);

      await tester.enterText(find.byType(TextField), 'ab12');
      await _frames(tester);

      expect(join.lookups, ['AB12']);
      expect(find.text(AppStrings.classroomJoinConfirm('5.A')), findsOneWidget);

      await tester.tap(find.text(AppStrings.classroomJoinYes));
      await _frames(tester);

      expect(join.joins, ['AB12']);
      expect(find.text(AppStrings.classroomJoinSuccess('5.A')), findsOneWidget);
      // The code dialog closed on success.
      expect(find.text(AppStrings.classroomJoinClassCodeHint), findsNothing);
    });

    testWidgets('switches to the six-box student code and back',
        (tester) async {
      await openDialog(tester, _FakeJoin.found());

      await tester.tap(find.text(AppStrings.classroomJoinUseStudentCode));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.classroomJoinCodeHint), findsOneWidget);
      expect(find.byKey(const ValueKey('code_box_5')), findsOneWidget);

      await tester.tap(find.text(AppStrings.classroomJoinUseClassCode));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('code_box_4')), findsNothing);
    });

    testWidgets('an unknown class code says so under the boxes',
        (tester) async {
      final join = _FakeJoin(
        ApiResult.failure('Kód třídy nebyl nalezen.', statusCode: 404),
      );
      await openDialog(tester, join);

      await tester.enterText(find.byType(TextField), 'ZZ99');
      await _frames(tester);

      expect(find.text(AppStrings.classroomJoinCodeNotFound), findsOneWidget);
      expect(join.joins, isEmpty);
    });

    testWidgets('an existing member reads "already in the class" and it stays',
        (tester) async {
      // The boxes are cleared after a refusal, which fires onChanged('') —
      // that used to wipe the message in the same frame it was set.
      final join = _FakeJoin(
        ApiResult.failure('Už jsi ve třídě 5.A.', statusCode: 409),
      );
      await openDialog(tester, join);

      await tester.enterText(find.byType(TextField), 'AB12');
      await _frames(tester);

      expect(find.text('Už jsi ve třídě 5.A.'), findsOneWidget);
      expect(join.joins, isEmpty);
    });
  });

  group('/join/:code deep link', () {
    testWidgets('a signed-in student is asked, then joined', (tester) async {
      final join = _FakeJoin.found();
      final container = await _pump(
        tester,
        join: join,
        action: joinClassroomFromDeepLink,
        parkedCode: 'AB12',
      );
      await _go(tester);

      expect(find.text(AppStrings.classroomJoinConfirm('5.A')), findsOneWidget);
      await tester.tap(find.text(AppStrings.classroomJoinYes));
      await tester.pumpAndSettle();

      expect(join.joins, ['AB12']);
      expect(find.text(AppStrings.classroomJoinSuccess('5.A')), findsOneWidget);
      expect(container.read(pendingClassroomJoinCodeProvider), isNull,
          reason: 'consumed once, so it cannot fire again on a rebuild');
    });

    testWidgets('an existing member gets the "already in the class" notice',
        (tester) async {
      final join = _FakeJoin(
        ApiResult.failure('Už jsi ve třídě 5.A.', statusCode: 409),
      );
      await _pump(
        tester,
        join: join,
        action: joinClassroomFromDeepLink,
        parkedCode: 'AB12',
      );
      await _go(tester);

      expect(find.text('Už jsi ve třídě 5.A.'), findsOneWidget);
      expect(join.joins, isEmpty);
    });

    testWidgets('an unknown code is reported, not silently dropped',
        (tester) async {
      final join = _FakeJoin(
        ApiResult.failure('Kód třídy nebyl nalezen.', statusCode: 404),
      );
      await _pump(
        tester,
        join: join,
        action: joinClassroomFromDeepLink,
        parkedCode: 'ZZ99',
      );
      await _go(tester);

      expect(find.text(AppStrings.classroomJoinCodeNotFound), findsOneWidget);
    });

    testWidgets('a malformed code never reaches the server', (tester) async {
      final join = _FakeJoin.found();
      await _pump(
        tester,
        join: join,
        action: joinClassroomFromDeepLink,
        parkedCode: 'hello',
      );
      await _go(tester);

      expect(join.lookups, isEmpty);
      expect(find.text(AppStrings.classroomJoinCodeNotFound), findsOneWidget);
    });

    testWidgets('a guest is sent to log in and the code waits for it',
        (tester) async {
      final join = _FakeJoin.found();
      final container = await _pump(
        tester,
        join: join,
        action: joinClassroomFromDeepLink,
        user: Stream.value(_user(guest: true)),
        parkedCode: 'AB12',
      );
      await _go(tester);

      expect(find.text(AppStrings.classroomJoinLoginRequired), findsOneWidget);
      await tester.tap(find.text(AppStrings.libraryLoggedOnlyAction));
      await tester.pumpAndSettle();

      expect(container.read(requestGuestLoginProvider), 1);
      expect(container.read(pendingClassroomJoinCodeProvider), 'AB12');
      expect(join.lookups, isEmpty);
    });

    testWidgets('nothing happens while the account is still loading',
        (tester) async {
      // A missing user row reads as "guest" to canOfferSignupProvider; acting
      // on it would tell a real account to log in during boot.
      final loading = StreamController<UsersTableData?>();
      addTearDown(loading.close);

      final join = _FakeJoin.found();
      final container = await _pump(
        tester,
        join: join,
        action: joinClassroomFromDeepLink,
        user: loading.stream,
        parkedCode: 'AB12',
      );
      expect(container.read(classroomJoinEligibilityProvider),
          ClassroomJoinEligibility.unknown);

      await _go(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(pendingClassroomJoinCodeProvider), 'AB12');
      expect(join.lookups, isEmpty);
    });

    testWidgets('a minor is told no and the code is dropped', (tester) async {
      final join = _FakeJoin.found();
      final container = await _pump(
        tester,
        join: join,
        action: joinClassroomFromDeepLink,
        minor: true,
        parkedCode: 'AB12',
      );
      await _go(tester);

      expect(find.text(AppStrings.classroomJoinNotAllowed), findsOneWidget);
      expect(container.read(pendingClassroomJoinCodeProvider), isNull);
      expect(join.lookups, isEmpty);
    });
  });
}
