import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../logic/auth_service.dart';
import '../logic/ride_rules.dart';

/// Ride group chat. Only members of the ride can read, stream or write.
class ChatEndpoint extends Endpoint {
  static String channelFor(int rideId) => 'ride_chat_$rideId';

  Future<void> _requireMember(
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
  }

  Future<RideMessage> sendMessage(
    Session session,
    String authToken,
    int rideId,
    String text,
  ) async {
    final user = await AuthService.requireUser(session, authToken);
    await _requireMember(session, rideId, user.userId);

    final ride = await Ride.db.findById(session, rideId);
    if (ride == null || ride.status == 'cancelled') {
      throw PoolMatesException(message: 'This ride was cancelled.');
    }
    final error = RideRules.validateMessage(text);
    if (error != null) throw PoolMatesException(message: error);

    // sender identity comes from the session, never from the client
    final saved = await RideMessage.db.insertRow(
      session,
      RideMessage(
        rideId: rideId,
        senderId: user.userId,
        senderName: user.name,
        text: text.trim(),
        sentAt: DateTime.now().toUtc(),
      ),
    );
    session.messages.postMessage(channelFor(rideId), saved);
    return saved;
  }

  /// Last 200 messages, oldest first.
  Future<List<RideMessage>> history(
    Session session,
    String authToken,
    int rideId,
  ) async {
    final user = await AuthService.requireUser(session, authToken);
    await _requireMember(session, rideId, user.userId);
    final rows = await RideMessage.db.find(
      session,
      where: (t) => t.rideId.equals(rideId),
      orderBy: (t) => t.sentAt,
      orderDescending: true,
      limit: 200,
    );
    return rows.reversed.toList();
  }

  Stream<RideMessage> rideChatStream(
    Session session,
    String authToken,
    int rideId,
  ) async* {
    final user = await AuthService.requireUser(session, authToken);
    await _requireMember(session, rideId, user.userId);
    yield* session.messages.createStream<RideMessage>(channelFor(rideId));
  }
}
