import 'package:poolmates_server/src/logic/ride_rules.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 1, 10, 0);
  final soon = now.add(const Duration(hours: 3));

  String? create({
    String type = 'offer',
    String origin = 'Campus',
    String destination = 'Airport',
    DateTime? dep,
    int seats = 4,
    double? fare = 1000,
  }) => RideRules.validateCreate(
    type: type,
    origin: origin,
    destination: destination,
    departAt: dep ?? soon,
    seatsTotal: seats,
    totalFare: fare,
    now: now,
  );

  group('validateCreate', () {
    test('accepts a normal ride', () => expect(create(), isNull));

    test('rejects bad type', () => expect(create(type: 'taxi'), isNotNull));

    test('rejects empty or identical places', () {
      expect(create(origin: '  '), isNotNull);
      expect(create(destination: ''), isNotNull);
      expect(create(origin: 'Campus', destination: 'campus '), isNotNull);
      expect(create(origin: 'Airport', destination: 'IGI Airport'), isNotNull);
    });

    test('rejects past and too-far departure', () {
      expect(create(dep: now.subtract(const Duration(minutes: 1))), isNotNull);
      expect(create(dep: now), isNotNull);
      expect(create(dep: now.add(const Duration(days: 31))), isNotNull);
      expect(create(dep: now.add(const Duration(days: 29))), isNull);
    });

    test('seat limits', () {
      expect(create(seats: 1), isNotNull);
      expect(create(seats: 9), isNotNull);
      expect(create(seats: 2), isNull);
      expect(create(seats: 8), isNull);
    });

    test('fare limits', () {
      expect(create(fare: 0), isNotNull);
      expect(create(fare: -5), isNotNull);
      expect(create(fare: 1e9), isNotNull);
      expect(create(fare: double.nan), isNotNull);
      expect(create(fare: null), isNull);
    });
  });

  group('seats', () {
    test('firstFreeSeat fills gaps and detects full', () {
      expect(RideRules.firstFreeSeat([0], 4), equals(1));
      expect(RideRules.firstFreeSeat([0, 1, 3], 4), equals(2));
      expect(RideRules.firstFreeSeat([0, 1, 2, 3], 4), isNull);
      expect(RideRules.firstFreeSeat([], 3), equals(0));
    });
  });

  group('fare', () {
    test('per head', () {
      expect(RideRules.farePerHead(1200, 3), equals(400.0));
      expect(RideRules.farePerHead(1000, 3), equals(333.33));
      expect(RideRules.farePerHead(null, 3), isNull);
      expect(RideRules.farePerHead(1000, 0), isNull);
    });
  });

  group('misc', () {
    test('isFemale', () {
      expect(RideRules.isFemale('female'), isTrue);
      expect(RideRules.isFemale(' Female '), isTrue);
      expect(RideRules.isFemale('male'), isFalse);
      expect(RideRules.isFemale('other'), isFalse);
      expect(RideRules.isFemale(null), isFalse);
    });

    test('validateMessage', () {
      expect(RideRules.validateMessage('hi'), isNull);
      expect(RideRules.validateMessage('   '), isNotNull);
      expect(RideRules.validateMessage('x' * 1001), isNotNull);
    });

    test('cleanTags trims, dedupes, caps', () {
      expect(
        RideRules.cleanTags([' Flutter ', 'flutter', '', 'ML']),
        equals(['flutter', 'ml']),
      );
      expect(
        RideRules.cleanTags(List.generate(30, (i) => 't$i')).length,
        equals(RideRules.maxTags),
      );
      expect(
        RideRules.cleanTags(['a' * 100]).first.length,
        equals(RideRules.maxTagLength),
      );
    });
  });
}
