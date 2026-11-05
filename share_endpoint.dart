import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Public "share my trip with family" link. No login needed, so it exposes
/// the minimum: route, time, organiser's first name and head-count.
class ShareEndpoint extends Endpoint {
  Future<PublicTripSummary?> getByToken(Session session, String token) async {
    // Tokens are 24 random bytes (~32 chars). Reject junk before touching the DB.
    if (token.length < 20 || token.length > 100) return null;

    final ride = await Ride.db.findFirstRow(
      session,
      where: (t) => t.shareToken.equals(token),
    );
    if (ride == null) return null;
    if (ride.shareExpiresAt.isBefore(DateTime.now().toUtc())) return null;

    final memberCount = await RideMember.db.count(
      session,
      where: (t) => t.rideId.equals(ride.id!),
    );

    return PublicTripSummary(
      origin: ride.origin,
      destination: ride.destination,
      departAt: ride.departAt,
      creatorFirstName: ride.creatorName.trim().split(' ').first,
      memberCount: memberCount,
      seatsTotal: ride.seatsTotal,
      womenOnly: ride.womenOnly,
      status: ride.status,
    );
  }
}
