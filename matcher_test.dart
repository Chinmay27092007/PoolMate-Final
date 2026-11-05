import 'package:poolmates_server/src/generated/protocol.dart';
import 'package:poolmates_server/src/logic/matcher.dart';
import 'package:test/test.dart';

void main() {
  // Fixed clock so tests never depend on the real time.
  final now = DateTime.utc(2026, 11, 1, 10, 0);
  final departAt = now.add(const Duration(hours: 2));

  UserProfile user(
    String id, {
    String gender = 'male',
    List<String> skills = const [],
    List<String> interests = const [],
    List<String> lookingFor = const [],
  }) => UserProfile(
    userId: id,
    campusId: 1,
    name: id,
    email: '$id@bennett.edu.in',
    branch: 'CSE',
    year: 2,
    gender: gender,
    skills: skills,
    interests: interests,
    lookingFor: lookingFor,
    createdAt: now,
  );

  Ride ride({
    DateTime? dep,
    String origin = 'Campus',
    String destination = 'Airport',
    int total = 4,
    int taken = 1,
    bool womenOnly = false,
    String status = 'open',
    String type = 'offer',
    int campusId = 1,
  }) => Ride(
    campusId: campusId,
    creatorId: 'c',
    creatorName: 'Creator',
    type: type,
    origin: origin,
    destination: destination,
    departAt: dep ?? departAt,
    seatsTotal: total,
    seatsTaken: taken,
    totalFare: 1200,
    womenOnly: womenOnly,
    status: status,
    shareToken: 'pm_token',
    shareExpiresAt: (dep ?? departAt).add(const Duration(hours: 24)),
    createdAt: now,
  );

  bool passes(
    Ride r, {
    String origin = 'campus',
    String destination = 'airport',
    int seats = 1,
    bool womenOnly = false,
    String gender = 'male',
    String? type,
    int campusId = 1,
  }) => RideMatcher.passesHardFilter(
    ride: r,
    campusId: campusId,
    origin: origin,
    destination: destination,
    departAt: departAt,
    seatsNeeded: seats,
    requesterWomenOnly: womenOnly,
    requesterGender: gender,
    rideType: type,
    now: now,
  );

  group('Skill score', () {
    test('rewards complementary skills and caps at 100', () {
      final me = user(
        'me',
        skills: ['developer'],
        interests: ['ai'],
        lookingFor: ['editor'],
      );
      final editor = user(
        'ed',
        skills: ['editor'],
        interests: ['ai'],
        lookingFor: ['developer'],
      );
      final other = user('ot', skills: ['robotics'], lookingFor: ['gamer']);

      final good = RideMatcher.calculateScore(me: me, candidate: editor);
      final none = RideMatcher.calculateScore(me: me, candidate: other);

      expect(good.score, equals(80)); // 40 + 30 + 10
      expect(none.score, equals(0));
      expect(none.reasons, equals(['Route & schedule match']));
    });

    test('score never exceeds 100', () {
      final me = user(
        'me',
        skills: ['a', 'b', 'c'],
        lookingFor: ['x', 'y', 'z'],
      );
      final cand = user(
        'c',
        skills: ['x', 'y', 'z'],
        lookingFor: ['a', 'b', 'c'],
      );
      expect(
        RideMatcher.calculateScore(me: me, candidate: cand).score,
        equals(100),
      );
    });
  });

  group('Hard filter', () {
    test('time window is +-30 minutes', () {
      expect(
        passes(ride(dep: departAt.add(const Duration(minutes: 20)))),
        isTrue,
      );
      expect(
        passes(ride(dep: departAt.add(const Duration(minutes: 45)))),
        isFalse,
      );
    });

    test('rides that already departed are never shown', () {
      final past = now.subtract(const Duration(minutes: 5));
      final r = ride(dep: past);
      expect(
        RideMatcher.passesHardFilter(
          ride: r,
          campusId: 1,
          origin: 'Campus',
          destination: 'Airport',
          departAt: past,
          seatsNeeded: 1,
          requesterWomenOnly: false,
          requesterGender: 'male',
          now: now,
        ),
        isFalse,
      );
    });

    test('full ride / not enough seats is rejected', () {
      expect(passes(ride(total: 4, taken: 4)), isFalse);
      expect(passes(ride(total: 4, taken: 3), seats: 2), isFalse);
      expect(passes(ride(total: 4, taken: 2), seats: 2), isTrue);
    });

    test('non-open status is rejected', () {
      expect(passes(ride(status: 'cancelled')), isFalse);
      expect(passes(ride(status: 'full')), isFalse);
    });

    test('other campus is rejected', () {
      expect(passes(ride(campusId: 2)), isFalse);
    });

    test('place aliases and punctuation still match', () {
      expect(
        passes(ride(destination: 'Airport'), destination: 'IGI Airport'),
        isTrue,
      );
      expect(
        passes(ride(destination: 'Airport T3'), destination: 'airport'),
        isTrue,
      );
      expect(passes(ride(origin: 'Campus'), origin: ' CAMPUS. '), isTrue);
      expect(
        passes(ride(destination: 'City Centre'), destination: 'airport'),
        isFalse,
      );
    });

    test('offer / request filter', () {
      final offer = ride(type: 'offer');
      expect(passes(offer, type: 'offer'), isTrue);
      expect(passes(offer, type: 'request'), isFalse);
      expect(passes(offer), isTrue); // null = any
    });

    group('women-only', () {
      final wo = ride(womenOnly: true);
      test('male cannot see women-only rides', () {
        expect(passes(wo, gender: 'male'), isFalse);
      });
      test('"other" and unknown genders cannot see women-only rides', () {
        expect(passes(wo, gender: 'other'), isFalse);
        expect(passes(wo, gender: ''), isFalse);
      });
      test('female can see them', () {
        expect(passes(wo, gender: 'female'), isTrue);
        expect(passes(wo, gender: 'Female'), isTrue);
      });
      test('requester who wants women-only skips mixed rides', () {
        expect(passes(ride(), gender: 'female', womenOnly: true), isFalse);
        expect(passes(wo, gender: 'female', womenOnly: true), isTrue);
      });
      test('a male asking for women-only gets nothing at all', () {
        expect(passes(wo, gender: 'male', womenOnly: true), isFalse);
        expect(passes(ride(), gender: 'male', womenOnly: true), isFalse);
      });
    });
  });
}
