import 'place_normalizer.dart';

/// Pure validation / business rules. No database, no Serverpod, so it is
/// cheap to unit test and the endpoints stay thin.
class RideRules {
  static const int minSeats = 2;
  static const int maxSeats = 8;
  static const int maxOpenRidesPerUser = 3;
  static const double maxFare = 100000;
  static const int maxDaysAhead = 30;
  static const int maxMessageLength = 1000;
  static const int maxPlaceLength = 80;
  static const int maxTags = 10;
  static const int maxTagLength = 30;

  static const Set<String> rideTypes = {'offer', 'request'};
  static const Set<String> genders = {'female', 'male', 'other'};

  static bool isFemale(String? gender) =>
      (gender ?? '').trim().toLowerCase() == 'female';

  /// Returns an error message, or null when the ride is acceptable.
  static String? validateCreate({
    required String type,
    required String origin,
    required String destination,
    required DateTime departAt,
    required int seatsTotal,
    required DateTime now,
    double? totalFare,
  }) {
    if (!rideTypes.contains(type)) {
      return "Ride type must be 'offer' or 'request'.";
    }
    final o = origin.trim();
    final d = destination.trim();
    if (o.isEmpty || d.isEmpty) {
      return 'Origin and destination are required.';
    }
    if (o.length > maxPlaceLength || d.length > maxPlaceLength) {
      return 'Place names must be at most $maxPlaceLength characters.';
    }
    if (PlaceNormalizer.samePlace(o, d)) {
      return 'Origin and destination cannot be the same place.';
    }
    final nowUtc = now.toUtc();
    final dep = departAt.toUtc();
    if (!dep.isAfter(nowUtc)) {
      return 'Departure time must be in the future.';
    }
    if (dep.isAfter(nowUtc.add(const Duration(days: maxDaysAhead)))) {
      return 'Rides can be posted at most $maxDaysAhead days ahead.';
    }
    if (seatsTotal < minSeats || seatsTotal > maxSeats) {
      return 'Seats must be between $minSeats and $maxSeats (including you).';
    }
    if (totalFare != null) {
      final fareError = validateFare(totalFare);
      if (fareError != null) return fareError;
    }
    return null;
  }

  static String? validateFare(double fare) {
    if (fare.isNaN || fare.isInfinite || fare <= 0 || fare > maxFare) {
      return 'Fare must be between 1 and ${maxFare.toInt()}.';
    }
    return null;
  }

  /// Lowest free seat number in 0..seatsTotal-1, or null when full.
  /// Seat 0 is the organiser.
  static int? firstFreeSeat(Iterable<int> takenSeatNumbers, int seatsTotal) {
    final taken = takenSeatNumbers.toSet();
    for (var i = 0; i < seatsTotal; i++) {
      if (!taken.contains(i)) return i;
    }
    return null;
  }

  static double? farePerHead(double? totalFare, int people) {
    if (totalFare == null || people <= 0) return null;
    return double.parse((totalFare / people).toStringAsFixed(2));
  }

  /// Returns an error message, or null when the chat text is acceptable.
  static String? validateMessage(String text) {
    final t = text.trim();
    if (t.isEmpty) return 'Message cannot be empty.';
    if (t.length > maxMessageLength) {
      return 'Message is too long (max $maxMessageLength characters).';
    }
    return null;
  }

  /// Trim, lowercase, drop empties/duplicates, cap length and count.
  static List<String> cleanTags(List<String> tags) {
    final out = <String>[];
    for (final raw in tags) {
      var t = raw.trim().toLowerCase();
      if (t.isEmpty) continue;
      if (t.length > maxTagLength) t = t.substring(0, maxTagLength);
      if (!out.contains(t)) out.add(t);
      if (out.length >= maxTags) break;
    }
    return out;
  }
}
