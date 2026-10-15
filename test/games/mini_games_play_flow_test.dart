// Wiring between the Minihry listing and the game engines (BR-TTB6UX).
//
// The rule under test: an attempt is a scarce resource (4/day for Sky Jumper),
// so /play must be called exactly when a run really starts — never for a game
// this build cannot open, and never twice for one tap.
//
//   flutter test test/games/mini_games_play_flow_test.dart
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/data/repositories/mini_games_repository.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/models/mini_game_model.dart';
import 'package:eduai/pages/doplnky_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The start button on the game's own ready screen.
final startButton = find.text(AppStrings.gameTapToStart);

class FakeMiniGamesRepository implements MiniGamesRepository {
  final List<MiniGame> games;

  final List<String> playCalls = [];
  final List<(int, int, int)> scoreCalls = [];

  /// When true, [play] behaves like a server that refused the attempt.
  bool refusePlay = false;

  FakeMiniGamesRepository(this.games);

  @override
  Future<MiniGameList> fetchList() async =>
      MiniGameList(items: games, level: 1);

  @override
  Future<MiniGameRun> play(String code) async {
    playCalls.add(code);
    if (refusePlay) throw Exception('locked');
    return MiniGameRun(game: games.firstWhere((g) => g.code == code), playId: 42);
  }

  @override
  Future<bool> submitScore(int playId, int score, int coins) async {
    scoreCalls.add((playId, score, coins));
    return true;
  }
}

/// An account with nothing to draw — the engine then falls back to its
/// primitive player, which is what these tests assert against.
class EmptyAvatarController extends AvatarController {
  @override
  Future<AvatarState> build() async => AvatarState.empty;
}

MiniGame game(String code, {bool playable = true}) => MiniGame(
      id: code.hashCode,
      code: code,
      title: 'Game $code',
      perex: 'perex',
      minLevel: 1,
      isPlayable: playable,
    );

Future<FakeMiniGamesRepository> pumpListing(
  WidgetTester tester,
  List<MiniGame> games,
) async {
  final repo = FakeMiniGamesRepository(games);

  // Phone surface. The default 800x600 test view is wide enough that the page
  // wraps itself in `DetailShell` (BR-KN9XUT) and pulls the whole app shell —
  // providers and all — into tests that are only about the play flow.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        miniGamesRepositoryProvider.overrideWithValue(repo),
        miniGamesListProvider.overrideWith((ref) async => repo.fetchList()),
        // The listing warms the avatar up so a run can start with a sprite in
        // hand; stubbed here so these tests never touch the real database.
        avatarControllerProvider.overrideWith(EmptyAvatarController.new),
      ],
      child: const MaterialApp(home: DoplnkyPage()),
    ),
  );
  await tester.pumpAndSettle();

  return repo;
}

void main() {
  testWidgets('a game with no engine in this build is not listed at all',
      (tester) async {
    final repo = await pumpListing(tester, [game('minigame_3')]);

    // No card, no play button — an unshipped game cannot spend an attempt
    // because it is not even offered.
    expect(find.text('Hrát'), findsNothing);
    expect(repo.playCalls, isEmpty);
  });

  testWidgets('a game with an engine spends the attempt and opens', (tester) async {
    final repo = await pumpListing(tester, [game('sky_jumper')]);

    await tester.tap(find.text('Hrát'));
    await tester.pumpAndSettle();

    expect(repo.playCalls, ['sky_jumper']);
    expect(startButton, findsOneWidget);
  });

  testWidgets('a refused attempt does not open the game', (tester) async {
    final repo = await pumpListing(tester, [game('sky_jumper')]);
    repo.refusePlay = true;

    await tester.tap(find.text('Hrát'));
    await tester.pumpAndSettle();

    expect(repo.playCalls, ['sky_jumper']);
    expect(startButton, findsNothing);
    expect(find.text('Hra teď není dostupná'), findsOneWidget);
  });

  testWidgets('a locked game cannot be started at all', (tester) async {
    final repo =
        await pumpListing(tester, [game('sky_jumper', playable: false)]);

    await tester.tap(find.text('Hrát'));
    await tester.pumpAndSettle();

    expect(repo.playCalls, isEmpty);
  });

  testWidgets('the score of a finished run is reported against that run',
      (tester) async {
    final repo = await pumpListing(tester, [game('sky_jumper')]);

    await tester.tap(find.text('Hrát'));
    await tester.pumpAndSettle();

    // Leave the engine the way the game-over button does.
    final context = tester.element(startButton);
    Navigator.of(context).pop(const MiniGameOutcome(score: 1234));
    await tester.pumpAndSettle();

    expect(repo.scoreCalls, [(42, 1234, 0)]);
  });

  testWidgets('the coins a run collected are reported with its score',
      (tester) async {
    // The server is what banks them (BR-HK9828), so losing them here loses
    // them altogether — the run is over and its attempt is already spent.
    final repo = await pumpListing(tester, [game('sky_jumper')]);

    await tester.tap(find.text('Hrát'));
    await tester.pumpAndSettle();

    final context = tester.element(startButton);
    Navigator.of(context).pop(const MiniGameOutcome(score: 800, coins: 17));
    await tester.pumpAndSettle();

    expect(repo.scoreCalls, [(42, 800, 17)]);
  });
}
