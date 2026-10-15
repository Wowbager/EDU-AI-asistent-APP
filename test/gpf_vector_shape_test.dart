import 'package:eduai/core/elo/elo_engine.dart';
import 'package:eduai/core/elo/gpf_vector_shape.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 35-slot shape guard in front of the strict Pilot 2 engine (BR-P2UAT2).
void main() {
  test('pads a short vector with the fill value', () {
    final fitted = fitGpfVector(<double?>[1.0, 2.0], null);
    expect(fitted, hasLength(kGpfDimensions));
    expect(fitted.sublist(0, 2), [1.0, 2.0]);
    expect(fitted.sublist(2).every((v) => v == null), isTrue);
  });

  test('truncates a long vector', () {
    final long = List<int>.generate(40, (i) => i);
    final fitted = fitGpfVector(long, 0);
    expect(fitted, hasLength(kGpfDimensions));
    expect(fitted.last, kGpfDimensions - 1);
  });

  test('copies an already well-shaped vector', () {
    final source = List<double>.filled(kGpfDimensions, 2.0);
    final fitted = fitGpfVector(source, 0.0);
    expect(fitted, source);
    fitted[0] = 0.0;
    expect(source[0], 2.0);
  });

  test('a short block vector no longer makes updateTask throw', () {
    final profil = List<double?>.filled(kGpfDimensions, 6.0);
    final res = EloEngine.updateTask(
      profilElo: profil,
      profilPocet: List<int>.filled(kGpfDimensions, 0),
      relationVector: fitGpfVector(<double>[2.0, 0.0], 0.0),
      eloVector: fitGpfVector(<double?>[6.0], null),
      itemPocet: fitGpfVector(<int>[], 0),
      score: 1.0,
    );
    expect(res.updatedIndices, [0]);
  });
}
