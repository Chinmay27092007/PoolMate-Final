import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../logic/auth_service.dart';
import '../logic/matcher.dart';
import '../logic/ride_rules.dart';

class MatchEndpoint extends Endpoint {
  /// Finds and ranks rides for the signed-in user.
  /// Campus and gender always come from the server-side profile, never the client.
  Future<List<MatchedRide>> findMatches(
    Session session,
    String authToken, {
    required String origin,
    required String destination,
    required DateTime departAt,
    required int seatsNeeded,
    required bool womenOnly,
    String? rideType,
  }) async {
    final me = await AuthService.requireUser(session, authToken);

    if (seatsNeeded < 1 || seatsNeeded > RideRules.maxSeats - 1) {
      throw PoolMatesException(message: 'Invalid number of seats.');
    }
    if (rideType != null && !RideRules.rideTypes.contains(rideType)) {
      throw PoolMatesException(message: 'Invalid ride type.');
    }

    final now = DateTime.now().toUtc();
    final target = departAt.toUtc();
    final window = Duration(minutes: RideMatcher.timeWindowMinutes);
    var from = target.subtract(window);
    if (from.isBefore(now)) from = now; // never show rides that already left
    final to = target.add(window);
    if (to.isBefore(from)) return [];

    // One query for candidate rides (campus, status, time window).
    final candidates = await Ride.db.find(
      session,
      where: (t) =>
          t.campusId.equals(me.campusId) &
          t.status.equals('open') &
          t.departAt.between(from, to),
    );

    final filtered = candidates
        .where(
          (r) =>
              r.creatorId != me.userId &&
              RideMatcher.passesHardFilter(
                ride: r,
                campusId: me.campusId,
                origin: origin,
                destination: destination,
                departAt: target,
                seatsNeeded: seatsNeeded,
                requesterWomenOnly: womenOnly,
                requesterGender: me.gender,
                rideType: rideType,
                now: now,
              ),
        )
        .toList();
    if (filtered.isEmpty) return [];

    final rideIds = filtered.map((r) => r.id!).toSet();

    // One query for all members, one for all their profiles (no N+1).
    final members = await RideMember.db.find(
      session,
      where: (t) => t.rideId.inSet(rideIds),
    );

    // Skip rides the user is already in.
    final alreadyIn = members
        .where((m) => m.userId == me.userId)
        .map((m) => m.rideId)
        .toSet();

    final userIds = members.map((m) => m.userId).toSet();
    final profiles = await UserProfile.db.find(
      session,
      where: (t) => t.userId.inSet(userIds),
    );
    final profileById = {for (final p in profiles) p.userId: p};

    final results = <MatchedRide>[];
    for (final ride in filtered) {
      if (alreadyIn.contains(ride.id)) continue;

      var bestScore = -1;
      var bestReasons = <String>['Route & schedule match'];
      for (final m in members.where((m) => m.rideId == ride.id)) {
        final candidate = profileById[m.userId];
        if (candidate == null) continue;
        final s = RideMatcher.calculateScore(me: me, candidate: candidate);
        if (s.score > bestScore) {
          bestScore = s.score;
          bestReasons = s.reasons;
        }
      }
      if (bestScore < 0) bestScore = 0;

      results.add(
        MatchedRide(
          ride: ride,
          score: bestScore,
          whyMatched: bestReasons,
          farePerHead: RideRules.farePerHead(
            ride.totalFare,
            ride.seatsTaken + seatsNeeded,
          ),
          projectedFarePerHead: RideRules.farePerHead(
            ride.totalFare,
            ride.seatsTotal,
          ),
        ),
      );
    }

    // Best score first; ties -> earliest departure.
    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : a.ride.departAt.compareTo(b.ride.departAt);
    });
    return results;
  }
}
