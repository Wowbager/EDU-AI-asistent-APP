// Shape guard for the GPF vectors handed to the ELO engine.
//
// The Pilot 2 engine (elo_engine.dart) validates its inputs strictly and
// throws on anything that is not exactly 35 slots long. Course content and
// synced profiles are meant to be 35 wide, but a block authored against a
// different dimension count, or a profile written by an older build, must not
// make the answer path throw — the previous engine silently walked the
// overlap. Fitting the vector up front keeps that tolerance: missing slots are
// filled, extra ones dropped.
library;

import 'elo_engine.dart';

/// [vector] resized to [kGpfDimensions] slots: padded with [fill] when short,
/// truncated when long. Always a fresh list, so callers keep their original.
List<T> fitGpfVector<T>(List<T> vector, T fill) {
  return List<T>.generate(
    kGpfDimensions,
    (i) => i < vector.length ? vector[i] : fill,
  );
}
