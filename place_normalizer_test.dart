import 'package:poolmates_server/src/logic/place_normalizer.dart';
import 'package:test/test.dart';

void main() {
  test('aliases map to one key', () {
    expect(
      PlaceNormalizer.key('Airport'),
      equals(PlaceNormalizer.key('IGI Airport')),
    );
    expect(PlaceNormalizer.key('airport, T3'), equals('airport'));
    expect(PlaceNormalizer.key('Bennett University'), equals('campus'));
  });

  test('different airports stay different', () {
    expect(PlaceNormalizer.samePlace('Airport', 'Noida Airport'), isFalse);
  });

  test('unknown places fall back to cleaned text', () {
    expect(PlaceNormalizer.samePlace('Sector 62', ' sector-62 '), isTrue);
    expect(PlaceNormalizer.samePlace('Sector 62', 'Sector 63'), isFalse);
  });

  test('empty is never the same place', () {
    expect(PlaceNormalizer.samePlace('', ''), isFalse);
    expect(PlaceNormalizer.samePlace('  ', '!!'), isFalse);
  });

  test('label gives a tidy display name', () {
    expect(PlaceNormalizer.label('igi airport'), equals('Airport'));
    expect(PlaceNormalizer.label('  Sector 62 '), equals('Sector 62'));
  });
}
