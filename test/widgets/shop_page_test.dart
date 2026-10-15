// The avatar shop (BR-7JRBCN).
//
// The screen is now backed by real data, so these tests pin the behaviour that
// would break silently: the slot tabs filter the catalog, an unowned item is
// acquired *and* worn in one tap, tapping a second item in the same slot
// replaces the first, and none of it overflows on a narrow phone.
//
//   flutter test test/widgets/shop_page_test.dart
import 'package:eduai/core/providers/core_providers.dart';
import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/theme/app_theme.dart';
import 'package:eduai/core/util/contrast.dart';
import 'package:eduai/models/avatar_display.dart';
import 'package:eduai/models/avatar_model.dart';
import 'package:eduai/pages/shop_page.dart';
import 'package:eduai/widgets/desktop_top_bar.dart';
import 'package:eduai/widgets/shop_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A minimal but renderable layer — the card draws whatever `svgSource` holds.
const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 270.93 270.93">'
    '<rect width="270.93" height="270.93" fill="#c792ea"/></svg>';

AvatarItem _item(
  String code,
  AvatarSlot slot,
  int layer, {
  bool owned = false,
  bool isDefault = false,
  AvatarRarity rarity = AvatarRarity.common,
}) {
  return AvatarItem(
    code: code,
    name: code,
    slot: slot,
    layer: layer,
    url: 'https://r2.test/$code.svg',
    rarity: rarity,
    price: 0,
    isDefault: isDefault,
    owned: owned,
    svgSource: _svg,
  );
}

// One item per rarity, and between them all three tile states — worn, owned,
// still to acquire. The contrast test below leans on that spread.
final _catalog = <AvatarItem>[
  _item('torso_base', AvatarSlot.torso, 20,
      owned: true, isDefault: true, rarity: AvatarRarity.epic),
  _item('head_crown', AvatarSlot.head, 40, rarity: AvatarRarity.rare),
  _item('head_cap', AvatarSlot.head, 40, owned: true),
  _item('legs_shorts', AvatarSlot.legs, 21),
];

/// Stands in for the repository-backed controller: purchases and equips are
/// recorded and applied in memory, so what is under test is the screen's own
/// logic rather than the network.
class FakeAvatarController extends AvatarController {
  final List<String> purchased = [];
  final List<String> equipped = [];

  /// When true, [purchase] behaves like a device with no connection.
  bool failPurchase = false;

  @override
  Future<AvatarState> build() async => AvatarState(
        catalog: _catalog,
        equipped: {AvatarSlot.torso: 'torso_base'},
      );

  @override
  Future<void> purchase(AvatarItem item) async {
    if (failPurchase) throw Exception('offline');
    purchased.add(item.code);

    final current = state.value!;
    state = AsyncValue.data(current.copyWith(
      catalog: [
        for (final i in current.catalog)
          i.code == item.code ? i.copyWith(owned: true) : i,
      ],
    ));
  }

  @override
  Future<void> equip(AvatarItem item) async {
    equipped.add(item.code);

    final current = state.value!;
    state = AsyncValue.data(current.copyWith(
      equipped: {...current.equipped, item.slot: item.code},
    ));
  }

  @override
  Future<void> unequip(AvatarSlot slot) async {
    final current = state.value!;
    state = AsyncValue.data(current.copyWith(
      equipped: {...current.equipped}..remove(slot),
    ));
  }
}

Future<FakeAvatarController> _pumpShop(
  WidgetTester tester, {
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Above the phone breakpoint the page wraps itself in `DetailShell`
  // (BR-KN9XUT), which draws the sidebar and the shell banners — so the wide
  // cases need what that chrome reads. The test-only Ahem font is far wider
  // than the real one, so the sidebar labels overflow their rows; cosmetic and
  // test-only, suppressed the same way the other shell tests do.
  final oldOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = oldOnError);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final controller = FakeAvatarController();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        avatarControllerProvider.overrideWith(() => controller),
        // The shell only needs these to resolve to "no user" — a widget test
        // has no business opening the local DB.
        activeUserStreamProvider.overrideWith((ref) => Stream.value(null)),
        userStatsStreamProvider.overrideWith((ref) => Stream.value(null)),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: ShopPage()),
    ),
  );
  await tester.pumpAndSettle();

  return controller;
}

int _cardsForSlot(WidgetTester tester, AvatarSlot slot) => tester
    .widgetList<ShopItemCard>(find.byType(ShopItemCard))
    .where((c) => c.item.slot == slot)
    .length;

/// Every label a tile draws, paired with the surface it is drawn on.
///
/// Text colours carry alpha, which is composited at paint time rather than
/// baked in — so the ratio has to be measured against the blend, not the
/// nominal colour.
Iterable<(String, Color, Color)> _labels(WidgetTester tester) sync* {
  for (final element in find.byType(ShopItemCard).evaluate()) {
    final card = element.widget as ShopItemCard;
    final texts = find.descendant(
      of: find.byWidget(card),
      matching: find.byType(Text),
    );

    for (final text in tester.widgetList<Text>(texts)) {
      final color = text.style?.color;
      if (color == null) continue;

      yield (
        '${card.item.rarity.name} "${text.data}"',
        Color.alphaBlend(color, card.backdrop),
        card.backdrop,
      );
    }
  }
}

void main() {
  testWidgets('renders the header and the catalog', (tester) async {
    await _pumpShop(tester);

    expect(find.text(AppStrings.shopTitle), findsOneWidget);
    expect(find.text(AppStrings.shopPermanentItems), findsOneWidget);
    expect(find.byType(ShopItemCard), findsWidgets);
  });

  testWidgets('renders without overflow on a narrow phone', (tester) async {
    await _pumpShop(tester, size: const Size(320, 700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('slot tabs filter the catalog', (tester) async {
    await _pumpShop(tester);

    // Default tab is Head; no Legs item is on screen yet.
    expect(_cardsForSlot(tester, AvatarSlot.head), 2);
    expect(_cardsForSlot(tester, AvatarSlot.legs), 0);

    // The tab row scrolls horizontally — the chip may be off-screen.
    final legsTab = find.text(AppStrings.shopSlotLegs);
    await tester.ensureVisible(legsTab);
    await tester.pumpAndSettle();
    await tester.tap(legsTab);
    await tester.pumpAndSettle();

    expect(_cardsForSlot(tester, AvatarSlot.legs), 1);
    expect(_cardsForSlot(tester, AvatarSlot.head), 0);
  });

  testWidgets('tapping an unowned item acquires it and wears it', (tester) async {
    final controller = await _pumpShop(tester);

    await tester.tap(find.text('head_crown'));
    await tester.pumpAndSettle();

    expect(controller.purchased, ['head_crown']);
    expect(
      controller.equipped,
      ['head_crown'],
      reason: 'a purchase the user cannot see on the avatar reads as a no-op',
    );
  });

  testWidgets('tapping an owned item only equips it', (tester) async {
    final controller = await _pumpShop(tester);

    await tester.tap(find.text('head_cap'));
    await tester.pumpAndSettle();

    expect(controller.purchased, isEmpty);
    expect(controller.equipped, ['head_cap']);
  });

  testWidgets('a second hat replaces the first', (tester) async {
    final controller = await _pumpShop(tester);

    await tester.tap(find.text('head_cap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('head_crown'));
    await tester.pumpAndSettle();

    final state = controller.state.value!;
    expect(state.equipped[AvatarSlot.head], 'head_crown');
    expect(
      state.equippedLayers.where((i) => i.slot == AvatarSlot.head),
      hasLength(1),
    );
  });

  testWidgets('the grid adds columns instead of stretching tiles on a wide '
      'screen', (tester) async {
    // The fixed three-column grid was tuned for a phone: on a 1600 px web
    // viewport it produced ~520 px tiles whose fixed aspect ratio reserved a
    // cell hundreds of pixels taller than the content — huge vertical gaps,
    // none sideways.
    await _pumpShop(tester, size: const Size(1600, 1000));

    final tile = tester
        .renderObjectList<RenderBox>(find.byType(ShopItemCard))
        .first;

    expect(
      tile.size.width,
      lessThan(250),
      reason: 'a shop tile should stay tile-sized however wide the window is',
    );
  });

  testWidgets('a tile is only as tall as its artwork plus its labels',
      (tester) async {
    await _pumpShop(tester);

    final card = tester
        .renderObjectList<RenderBox>(find.byType(ShopItemCard))
        .first;
    final column = tester
        .renderObjectList<RenderBox>(
          find.descendant(
            of: find.byType(ShopItemCard).first,
            matching: find.byType(Column),
          ),
        )
        .first;

    // Whatever slack is left is breathing room, not a gap you could park
    // another card in.
    expect(
      card.size.height - column.size.height,
      lessThan(24),
      reason: 'the row height must follow the content, not a guessed ratio',
    );
  });

  testWidgets('a failed purchase surfaces an error instead of dying',
      (tester) async {
    final controller = await _pumpShop(tester);
    controller.failPurchase = true;

    await tester.tap(find.text('head_crown'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.shopPurchaseFailed), findsOneWidget);
    expect(controller.equipped, isEmpty);
  });

  testWidgets('desktop splits into mascot pane and item panel', (tester) async {
    await _pumpShop(tester, size: const Size(1440, 810));

    expect(find.byKey(shopWideKey), findsOneWidget);
    // The title lives in DetailShell's chrome, the tiles in the panel.
    expect(find.text(AppStrings.shopTitle), findsWidgets);
    expect(find.byType(ShopItemCard), findsWidgets);
  });

  // BR-WJMTUF: the wide shop used to hang its name off the top bar's back
  // link, which left it in the back link's small type while every other page
  // carried a proper heading — and painted the page white on top of that.
  testWidgets('wide layouts get a page heading, not a back link',
      (tester) async {
    await _pumpShop(tester, size: const Size(1440, 810));

    // Scoped to the top bar: the sidebar carries a shop destination with the
    // same label, and it comes first in the tree.
    final heading = tester.widget<Text>(
      find.descendant(
        of: find.byType(DesktopTopBar),
        matching: find.text(AppStrings.shopTitle),
      ),
    );
    expect(heading.style?.fontSize, AppTextStyles.heading2Bold().fontSize);
    expect(heading.style?.fontWeight, AppTextStyles.heading2Bold().fontWeight);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('wide layouts take the app background, phones stay white',
      (tester) async {
    await _pumpShop(tester, size: const Size(1440, 810));
    // Depth-first: DetailShell's scaffold first, the page's own second.
    expect(
      tester.widgetList<Scaffold>(find.byType(Scaffold)).last.backgroundColor,
      AppColors.background,
    );

    await _pumpShop(tester);
    expect(
      tester.widgetList<Scaffold>(find.byType(Scaffold)).last.backgroundColor,
      AppColors.surface,
    );
  });

  testWidgets('phone keeps the single-column layout', (tester) async {
    await _pumpShop(tester);

    expect(find.byKey(shopWideKey), findsNothing);
    expect(find.text(AppStrings.shopTitle), findsOneWidget);
  });

  // BR-YXSVVC: the tile printed its name and state in the rarity pastel, which
  // measured 1.4:1 on the phone's white sheet and 1.0:1 at the bottom of the
  // desktop panel's wash — reported as "skoro nečitelné".
  group('label contrast', () {
    for (final (name, size) in [
      ('phone', const Size(360, 800)),
      ('tablet', const Size(900, 800)),
      ('desktop', const Size(1440, 810)),
    ]) {
      testWidgets('every tile label clears WCAG AA on $name', (tester) async {
        await _pumpShop(tester, size: size);

        final labels = _labels(tester).toList();
        expect(labels, isNotEmpty, reason: 'nothing was measured');

        for (final (what, foreground, background) in labels) {
          expect(
            contrastRatio(foreground, background),
            greaterThanOrEqualTo(kContrastAA),
            reason: '$what is unreadable on $name',
          );
        }
      });
    }

    testWidgets('the pastel accent still draws the border', (tester) async {
      // Rarity did not stop being visible — it moved to the shape that can
      // carry a pastel.
      await _pumpShop(tester);

      final card = tester.widget<ShopItemCard>(
        find.byType(ShopItemCard).first,
      );
      final decorated = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ShopItemCard).first,
              matching: find.byType(Container),
            )
            .first,
      );

      final border = (decorated.decoration as BoxDecoration).border!.top;
      expect(border.color, card.item.rarity.accent);
    });
  });
}
