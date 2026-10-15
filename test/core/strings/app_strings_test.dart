import 'package:eduai/core/strings/app_strings.dart';
import 'package:eduai/core/strings/locale_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// A missing key never throws — `_t` quietly falls back to another language —
/// so a forgotten translation is invisible at runtime. These tests are the
/// only thing standing between "we added a string" and "Slovak users read it
/// in Czech".
void main() {
  final tables = AppStrings.translationTables;

  // Restore the default so a locale set here cannot leak into other tests.
  tearDown(() => LocaleManager.notifier.value = AppLocale.cs);

  group('translation tables', () {
    test('cover every supported locale', () {
      expect(tables.keys.toSet(), AppLocale.values.toSet());
    });

    test('hold identical key sets', () {
      final reference = tables[AppLocale.cs]!.keys.toSet();

      for (final entry in tables.entries) {
        final keys = entry.value.keys.toSet();

        expect(
          keys.difference(reference),
          isEmpty,
          reason: '${entry.key.code} has keys Czech does not',
        );
        expect(
          reference.difference(keys),
          isEmpty,
          reason: '${entry.key.code} is missing keys Czech has',
        );
      }
    });

    test('have no blank values', () {
      for (final entry in tables.entries) {
        for (final pair in entry.value.entries) {
          expect(
            pair.value.trim(),
            isNotEmpty,
            reason: '${entry.key.code}/${pair.key} is blank',
          );
        }
      }
    });
  });

  group('lookup', () {
    test('resolves each locale to its own table', () {
      for (final locale in AppLocale.values) {
        LocaleManager.notifier.value = locale;

        expect(AppStrings.profileLanguage, tables[locale]!['profileLanguage']);
      }
    });

    test('interpolated strings differ per locale', () {
      LocaleManager.notifier.value = AppLocale.cs;
      expect(AppStrings.lessonTitle(2, 'Buňka'), 'Lekce 2: Buňka');

      LocaleManager.notifier.value = AppLocale.sk;
      expect(AppStrings.lessonTitle(2, 'Bunka'), 'Lekcia 2: Bunka');

      LocaleManager.notifier.value = AppLocale.en;
      expect(AppStrings.lessonTitle(2, 'Cell'), 'Lesson 2: Cell');
    });
  });

  // The guest is promised saved progress, not "full access" (BR-FZE5NZ) — the
  // account is free, so a paywall-shaped prompt was the wrong pitch. The
  // sentence is drawn twice, in the e-mail banner and in the sidebar's
  // register card, so both keys are pinned and the card keeps its own break.
  group('guest prompt', () {
    test('offers saved progress in Czech', () {
      expect(
        tables[AppLocale.cs]!['bannerGuestMessage'],
        'Postup se uloží až po přihlášení.',
      );
      expect(
        tables[AppLocale.cs]!['shellGuestCtaTitle'],
        'Postup se uloží\naž po přihlášení.',
      );
    });

    test('drops the old full-access pitch in every locale', () {
      const keys = ['bannerGuestMessage', 'shellGuestCtaTitle'];

      for (final entry in tables.entries) {
        for (final key in keys) {
          expect(
            entry.value[key]!.toLowerCase(),
            isNot(anyOf(
              contains('přístup'),
              contains('prístup'),
              contains('full access'),
            )),
            reason: '${entry.key.code}/$key still sells access',
          );
        }
      }
    });
  });

  group('AppLocale', () {
    test('exposes a distinct code and short label per locale', () {
      expect(
        AppLocale.values.map((l) => l.code).toSet().length,
        AppLocale.values.length,
      );
      expect(
        AppLocale.values.map((l) => l.shortLabel).toSet().length,
        AppLocale.values.length,
      );
    });

    test('fromCode falls back to Czech for unknown or null input', () {
      expect(AppLocale.fromCode('sk'), AppLocale.sk);
      expect(AppLocale.fromCode('de'), AppLocale.cs);
      expect(AppLocale.fromCode(null), AppLocale.cs);
    });
  });
}
