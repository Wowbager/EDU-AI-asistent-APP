import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:eduai/core/consent/age_threshold.dart';

void main() {
  group('AgeThreshold', () {
    setUp(() => AgeThreshold.resetForTest());

    test('returns 15 for CZ and 16 for SK', () {
      expect(AgeThreshold.forCountry('CZ'), 15);
      expect(AgeThreshold.forCountry('SK'), 16);
    });

    test('is case insensitive', () {
      expect(AgeThreshold.forCountry('sk'), 16);
    });

    // The server (ConsentService::ageThreshold()) does NOT fall back to a
    // separately configured default for an unresolved country — it falls
    // back to the highest threshold it knows about. Telling a parent the
    // limit is higher than their country's is harmless; understating it
    // is not. An unknown country must fail conservative the same way here.
    test('falls back to the highest known threshold for an unknown or missing country', () {
      expect(AgeThreshold.forCountry('DE'), 16);
      expect(AgeThreshold.forCountry(null), 16);
      expect(AgeThreshold.forCountry(''), 16);
    });

    test('server config overrides the bundled defaults', () {
      AgeThreshold.applyServerConfig(
        thresholds: {'CZ': 15, 'SK': 16, 'PL': 13},
        defaultThreshold: 14,
      );

      expect(AgeThreshold.forCountry('PL'), 13);
      // Still the highest of the *server-supplied* thresholds (16), not the
      // passed-in defaultThreshold (14) — same conservative rule as above.
      expect(AgeThreshold.forCountry('DE'), 16);

      AgeThreshold.resetForTest();
      expect(AgeThreshold.forCountry('PL'), 16);
    });

    test('an empty server threshold map is rejected, not adopted', () {
      // A malformed /api/consent/config response must not wipe out the
      // bundled fallback the offline-first gate depends on.
      AgeThreshold.applyServerConfig(thresholds: {}, defaultThreshold: 99);

      expect(AgeThreshold.forCountry('CZ'), 15);
      expect(AgeThreshold.forCountry('DE'), 16);
    });
  });

  group('AgeThreshold.knownCountries', () {
    setUp(() => AgeThreshold.resetForTest());

    test('bundled defaults, sorted', () {
      expect(AgeThreshold.knownCountries, ['CZ', 'SK']);
    });

    // This is what lets the age gate's country picker follow the server
    // instead of a hardcoded CZ/SK pair (see AgeGatePage) — adding a market
    // becomes a config change, not an app release.
    test('reflects a server override and stays sorted regardless of input order', () {
      AgeThreshold.applyServerConfig(
        thresholds: {'SK': 16, 'PL': 13, 'CZ': 15},
        defaultThreshold: 14,
      );

      expect(AgeThreshold.knownCountries, ['CZ', 'PL', 'SK']);
    });

    test('an empty server threshold map leaves the bundled countries in place', () {
      AgeThreshold.applyServerConfig(thresholds: {}, defaultThreshold: 99);

      expect(AgeThreshold.knownCountries, ['CZ', 'SK']);
    });
  });

  group('AgeThreshold.detectCountry', () {
    test('no region: a locale with only a language tag resolves to unknown', () {
      // A device set to plain "Czech" with no country configured must not be
      // guessed at — the gate's country-confirmation step is what resolves
      // this, not a silent assumption baked into detection.
      expect(AgeThreshold.detectCountry(const Locale('cs')), isNull);
      expect(AgeThreshold.detectCountry(const Locale('de')), isNull);
    });

    test('cs_SK: an explicit region wins over the language tag', () {
      // This is exactly the mismatch the gate's confirmation step exists
      // for: a Czech-language locale is not proof of being in Czechia. Here
      // the locale *does* carry a region (SK), and that must be trusted over
      // the language subtag (cs) — the two disagree and the region is the
      // more specific signal.
      expect(AgeThreshold.detectCountry(const Locale('cs', 'SK')), 'SK');
    });

    test('sk with no region still resolves to SK', () {
      expect(AgeThreshold.detectCountry(const Locale('sk')), 'SK');
    });

    test('web: a browser-reported language-only locale is handled the same as native', () {
      // Browsers commonly hand Flutter a bare language subtag (no region)
      // when the OS/browser locale has none configured. detectCountry must
      // not special-case the platform — same fallback either way.
      expect(AgeThreshold.detectCountry(const Locale('en')), isNull);
    });

    test('an unconfigured region is still reported as-is, not swallowed', () {
      expect(AgeThreshold.detectCountry(const Locale('de', 'AT')), 'AT');
    });
  });
}
