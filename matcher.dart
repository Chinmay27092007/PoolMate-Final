import '../generated/protocol.dart';
import 'place_normalizer.dart';

class MatchScoreResult {
  final int score;
  final List<String> reasons;

  const MatchScoreResult({required this.score, required this.reasons});
}

class RideMatcher {
  static const int timeWindowMinutes = 30;

  static Set<String> normalizeTags(List<String> tags) {
    return tags
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  /// Calculates the skill score between requester and candidate member.
  /// a = |candidate.skills ∩ me.lookingFor|
  /// b = |me.skills ∩ candidate.lookingFor|
  /// c = |candidate.interests ∩ me.interests|
  /// score = min(100, 40*a + 30*b + 10*c)
  static MatchScoreResult calculateScore({
    required UserProfile me,
    required UserProfile candidate,
  }) {
    final mySkills = normalizeTags(me.skills);
    final myInterests = normalizeTags(me.interests);
    final myLookingFor = normalizeTags(me.lookingFor);

    final candidateSkills = normalizeTags(candidate.skills);
    final candidateInterests = normalizeTags(candidate.interests);
    final candidateLookingFor = normalizeTags(candidate.lookingFor);

    final a = candidateSkills.intersection(myLookingFor);
    final b = mySkills.intersection(candidateLookingFor);
    final c = candidateInterests.intersection(myInterests);

    final rawScore = 40 * a.length + 30 * b.length + 10 * c.length;
    final score = rawScore > 100 ? 100 : rawScore;

    final reasons = <String>[];
    for (final skill in a) {
      reasons.add("Has: ${_capitalize(skill)} — you're looking for it");
    }
    for (final looking in b) {
      reasons.add("Looking for: ${_capitalize(looking)} — you have it");
    }
    for (final interest in c) {
      reasons.add("Shared interest: ${_capitalize(interest)}");
    }

    if (reasons.isEmpty) {
      reasons.add("Route & schedule match");
    }

    return MatchScoreResult(score: score, reasons: reasons);
  }

  /// Hard filters. A ride must pass all of them to be shown at all.
  ///
  /// [now] is injectable so tests are deterministic; it defaults to the clock.
  /// [rideType] ('offer' / 'request') narrows results when given; null = any.
  static bool passesHardFilter({
    required Ride ride,
    required int campusId,
    required String origin,
    required String destination,
    required DateTime departAt,
    required int seatsNeeded,
    required bool requesterWomenOnly,
    required String requesterGender,
    String? rideType,
    DateTime? now,
  }) {
    final nowUtc = (now ?? DateTime.now()).toUtc();

    // 1. Same campus
    if (ride.campusId != campusId) return false;

    // 2. Same route (tolerant of case, punctuation and common aliases)
    if (!PlaceNormalizer.samePlace(ride.origin, origin)) return false;
    if (!PlaceNormalizer.samePlace(ride.destination, destination)) return false;

    // 3. Has not departed yet, and departs within +-30 min of the request
    final rideDeparts = ride.departAt.toUtc();
    if (!rideDeparts.isAfter(nowUtc)) return false;
    final diffMinutes = rideDeparts
        .difference(departAt.toUtc())
        .inMinutes
        .abs();
    if (diffMinutes > timeWindowMinutes) return false;

    // 4. Optional offer/request filter
    if (rideType != null && ride.type != rideType) return false;

    // 5. Status open and enough free seats
    final freeSeats = ride.seatsTotal - ride.seatsTaken;
    if (ride.status.toLowerCase() != 'open' || freeSeats < seatsNeeded) {
      return false;
    }

    // 6. Women-only gating
    final isRequesterFemale = requesterGender.trim().toLowerCase() == 'female';
    if (ride.womenOnly && !isRequesterFemale) {
      return false; // Non-female users cannot see or join women-only rides
    }
    if (requesterWomenOnly && !ride.womenOnly) {
      return false; // Requester only wants women-only rides
    }

    return true;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
