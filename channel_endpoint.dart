import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../logic/auth_service.dart';
import '../logic/ride_rules.dart';

/// Campus-wide community channels (#general, #airport-runs, ...).
/// A user only ever sees channels of their own campus.
class ChannelEndpoint extends Endpoint {
  static String streamName(int channelId) => 'channel_msg_$channelId';

  Future<Channel> _channelFor(
    Session session,
    UserProfile user,
    int channelId,
  ) async {
    final ch = await Channel.db.findById(session, channelId);
    if (ch == null || ch.campusId != user.campusId) {
      throw PoolMatesException(message: 'Channel not found.');
    }
    return ch;
  }

  Future<List<Channel>> list(Session session, String authToken) async {
    final user = await AuthService.requireUser(session, authToken);
    return Channel.db.find(
      session,
      where: (t) => t.campusId.equals(user.campusId),
      orderBy: (t) => t.name,
    );
  }

  Future<List<ChannelMessage>> history(
    Session session,
    String authToken,
    int channelId,
  ) async {
    final user = await AuthService.requireUser(session, authToken);
    await _channelFor(session, user, channelId);
    final rows = await ChannelMessage.db.find(
      session,
      where: (t) => t.channelId.equals(channelId),
      orderBy: (t) => t.sentAt,
      orderDescending: true,
      limit: 200,
    );
    return rows.reversed.toList();
  }

  Future<ChannelMessage> sendChannelMessage(
    Session session,
    String authToken,
    int channelId,
    String text,
  ) async {
    final user = await AuthService.requireUser(session, authToken);
    await _channelFor(session, user, channelId);
    final error = RideRules.validateMessage(text);
    if (error != null) throw PoolMatesException(message: error);

    final saved = await ChannelMessage.db.insertRow(
      session,
      ChannelMessage(
        channelId: channelId,
        senderId: user.userId,
        senderName: user.name,
        text: text.trim(),
        sentAt: DateTime.now().toUtc(),
      ),
    );
    session.messages.postMessage(streamName(channelId), saved);
    return saved;
  }

  Stream<ChannelMessage> channelStream(
    Session session,
    String authToken,
    int channelId,
  ) async* {
    final user = await AuthService.requireUser(session, authToken);
    await _channelFor(session, user, channelId);
    yield* session.messages.createStream<ChannelMessage>(streamName(channelId));
  }
}
