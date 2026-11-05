import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../logic/auth_service.dart';
import '../logic/place_normalizer.dart';
import '../logic/ride_rules.dart';

class RideEndpoint extends Endpoint {
  static String channelFor(int rideId) => 'ride_update_$rideId';

  Future<Ride> create(
    Session session,
    String authToken, {
    required String type,
    required String origin,
    required String destination,
    required DateTime departAt,
    required int seatsTotal,
    double? totalFare,
    required bool womenOnly,
  }) async {
    final user = await AuthService.requireUser(session, authToken);
    final now = DateTime.now().toUtc();

    final error = RideRules.validateCreate(
      type: type,
      origin: origin,
      destination: destination,
      departAt: departAt,
      seatsTotal: seatsTotal,
      totalFare: totalFare,
      now: now,
    );
    if (error != null) throw PoolMatesException(message: error);

    // Strict: a profile that is not female can never create a women-only ride.
    if (womenOnly && !RideRules.isFemale(user.gender)) {
      throw PoolMatesException(
        message: 'Women-only rides can only be created by women.',
      );
    }

    final active = await Ride.db.count(
      session,
      where: (t) =>
          t.creatorId.equals(user.userId) & t.status.inSet({'open', 'full'}),
    );
    if (active >= RideRules.maxOpenRidesPerUser) {
      throw PoolMatesException(
        message:
            'You already have ${RideRules.maxOpenRidesPerUser} active rides. Cancel one first.',
      );
    }

    final dep = departAt.toUtc();
    final ride = await Ride.db.insertRow(
      session,
      Ride(
        campusId: user.campusId,
        creatorId: user.userId,
        creatorName: user.name,
        type: type,
        origin: PlaceNormalizer.label(origin),
        destination: PlaceNormalizer.label(destination),
        departAt: dep,
        seatsTotal: seatsTotal,
        seatsTaken: 1,
        totalFare: totalFare,
        womenOnly: womenOnly,
        status: 'open',
        shareToken: 'pm_${AuthService.randomToken(bytes: 24)}',
        shareExpiresAt: dep.add(const Duration(hours: 24)),
        createdAt: now,
      ),
    );

    await RideMember.db.insertRow(
      session,
      RideMember(
        rideId: ride.id!,
        userId: user.userId,
        userName: user.name,
        userGender: user.gender,
        role: 'creator',
        seatNo: 0,
        joinedAt: now,
      ),
    );
    return ride;
  }

  /// Visible to the same campus; women-only rides only to women (or members).
  Future<Ride> get(Session session, String authToken, int rideId) async {
    final user = await AuthService.requireUser(session, authToken);
    return _visibleRide(session, user, rideId);
  }

  Future<List<Ride>> listMine(Session session, String authToken) async {
    final user = await AuthService.requireUser(session, authToken);
    final memberships = await RideMember.db.find(
      session,
      where: (t) => t.userId.equals(user.userId),
    );
    if (memberships.isEmpty) return [];
    final ids = memberships.map((m) => m.rideId).toSet();
    return Ride.db.find(
      session,
      where: (t) => t.id.inSet(ids),
      orderBy: (t) => t.departAt,
      orderDescending: true,
    );
  }

  /// Only people already in the ride can see who else is in it.
  Future<List<RideMember>> getMembers(
    Session session,
    String authToken,
    int rideId,
  ) async {
    final user = await AuthService.requireUser(session, authToken);
    await _requireMember(session, rideId, user.userId);
    return RideMember.db.find(
      session,
      where: (t) => t.rideId.equals(rideId),
      orderBy: (t) => t.seatNo,
    );
  }

  Future<Ride> join(Session session, String authToken, int rideId) async {
    final user = await AuthService.requireUser(session, authToken);
    final ride = await _visibleRide(session, user, rideId);
    final now = DateTime.now().toUtc();

    final existing = await RideMember.db.findFirstRow(
      session,
      where: (t) => t.rideId.equals(rideId) & t.userId.equals(user.userId),
    );
    if (existing != null) return ride; // already in: idempotent

    if (ride.status != 'open') {
      throw PoolMatesException(message: 'This ride is no longer open.');
    }
    if (!ride.departAt.toUtc().isAfter(now)) {
      throw PoolMatesException(message: 'This ride has already departed.');
    }

    final members = await RideMember.db.find(
      session,
      where: (t) => t.rideId.equals(rideId),
    );
    final seat = RideRules.firstFreeSeat(
      members.map((m) => m.seatNo),
      ride.seatsTotal,
    );
    if (seat == null) {
      throw PoolMatesException(message: 'This ride is full.');
    }

    try {
      // The unique (rideId, seatNo) index rejects a second person grabbing
      // the same seat, so overbooking cannot happen even under a race.
      await RideMember.db.insertRow(
        session,
        RideMember(
          rideId: rideId,
          userId: user.userId,
          userName: user.name,
          userGender: user.gender,
          role: 'member',
          seatNo: seat,
          joinedAt: now,
        ),
      );
    } catch (_) {
      final nowMember = await RideMember.db.findFirstRow(
        session,
        where: (t) => t.rideId.equals(rideId) & t.userId.equals(user.userId),
      );
      if (nowMember != null) return ride;
      throw PoolMatesException(
        message: 'That seat was just taken. Please try again.',
      );
    }

    final updated = await _syncRide(session, rideId);
    session.messages.postMessage(channelFor(rideId), updated);
    return updated;
  }

  Future<Ride> leave(Session session, String authToken, int rideId) async {
    final user = await AuthService.requireUser(session, authToken);
    final ride = await Ride.db.findById(session, rideId);
    if (ride == null) throw PoolMatesException(message: 'Ride not found.');

    final member = await _requireMember(session, rideId, user.userId);
    if (member.role == 'creator') {
      throw PoolMatesException(
        message: 'As the organiser you cannot leave your own ride. Cancel it instead.',
      );
    }
    if (!ride.departAt.toUtc().isAfter(DateTime.now().toUtc())) {
      throw PoolMatesException(message: 'This ride has already departed.');
    }

    await RideMember.db.deleteRow(session, member);
    final updated = await _syncRide(session, rideId);
    session.messages.postMessage(channelFor(rideId), updated);
    return updated;
  }

  Future<Ride> cancel(Session session, String authToken, int rideId) async {
    final user = await AuthService.requireUser(session, authToken);
    final ride = await Ride.db.findById(session, rideId);
    if (ride == null) throw PoolMatesException(message: 'Ride not found.');
    if (ride.creatorId != user.userId) {
      throw PoolMatesException(
        message: 'Only the organiser can cancel this ride.',
      );
    }
    ride.status = 'cancelled';
    final updated = await Ride.db.updateRow(session, ride);
    session.messages.postMessage(channelFor(rideId), updated);
    return updated;
  }

  Future<Ride> setFare(
    Session session,
    String authToken,
    int rideId,
    double totalFare,
  ) async {
    final user = await AuthService.requireUser(session, authToken);
    final ride = await Ride.db.findById(session, rideId);
    if (ride == null) throw PoolMatesException(message: 'Ride not found.');
    if (ride.creatorId != user.userId) {
      throw PoolMatesException(
        message: 'Only the organiser can change the fare.',
      );
    }
    if (ride.status == 'cancelled') {
      throw PoolMatesException(message: 'This ride was cancelled.');
    }
    final error = RideRules.validateFare(totalFare);
    if (error != null) throw PoolMatesException(message: error);

    ride.totalFare = totalFare;
    final updated = await Ride.db.updateRow(session, ride);
    session.messages.postMessage(channelFor(rideId), updated);
    return updated;
  }

  // ---------------------------------------------------------------- helpers

  /// Loads a ride the user is allowed to see, else throws "not found"
  /// (same message for missing / other campus / hidden women-only).
  static Future<Ride> _visibleRide(
    Session session,
    UserProfile user,
    int rideId,
  ) async {
    final ride = await Ride.db.findById(session, rideId);
    if (ride == null || ride.campusId != user.campusId) {
      throw PoolMatesException(message: 'Ride not found.');
    }
    if (ride.womenOnly && !RideRules.isFemale(user.gender)) {
      final isMember = await RideMember.db.findFirstRow(
        session,
        where: (t) => t.rideId.equals(rideId) & t.userId.equals(user.userId),
      );
      if (isMember == null) {
        throw PoolMatesException(message: 'Ride not found.');
      }
    }
    return ride;
  }

  static Future<RideMember> _requireMember(
    Session session,
    int rideId,
    String userId,
  ) async {
    final m = await RideMember.db.findFirstRow(
      session,
      where: (t) => t.rideId.equals(rideId) & t.userId.equals(userId),
    );
    if (m == null) {
      throw PoolMatesException(message: 'You are not part of this ride.');
    }
    return m;
  }

  /// Recomputes seatsTaken/status from the real member rows, so the cached
  /// numbers can never drift from the truth.
  static Future<Ride> _syncRide(Session session, int rideId) async {
    final count = await RideMember.db.count(
      session,
      where: (t) => t.rideId.equals(rideId),
    );
    final ride = (await Ride.db.findById(session, rideId))!;
    ride.seatsTaken = count;
    if (ride.status != 'cancelled') {
      ride.status = count >= ride.seatsTotal ? 'full' : 'open';
    }
    return Ride.db.updateRow(session, ride);
  }
}
