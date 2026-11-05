import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Server-side identity. Endpoints never trust a client-supplied userId:
/// they receive an opaque session token and resolve the user from it.
class AuthService {
  static final Random _rng = Random.secure();
  static const Duration sessionLifetime = Duration(days: 30);

  static String sha256Hex(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  /// Cryptographically secure URL-safe token (default 256 bits).
  static String randomToken({int bytes = 32}) {
    final data = List<int>.generate(bytes, (_) => _rng.nextInt(256));
    return base64Url.encode(data).replaceAll('=', '');
  }

  static String randomOtp() => (_rng.nextInt(900000) + 100000).toString();

  static String newUserId() => 'u_${randomToken(bytes: 12)}';

  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Lowercases, validates and strips "+tag" so one person = one account.
  static String normalizeEmail(String raw) {
    final e = raw.trim().toLowerCase();
    final parts = e.split('@');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      throw PoolMatesException(message: 'Please enter a valid email address.');
    }
    final local = parts[0].split('+').first;
    final domain = parts[1];
    if (local.isEmpty ||
        !RegExp(r'^[a-z0-9._-]+$').hasMatch(local) ||
        !RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$').hasMatch(domain)) {
      throw PoolMatesException(message: 'Please enter a valid email address.');
    }
    return '$local@$domain';
  }

  /// Resolves the signed-in user from a session token or throws.
  static Future<UserProfile> requireUser(
    Session session,
    String? authToken,
  ) async {
    if (authToken == null || authToken.length < 20 || authToken.length > 200) {
      throw PoolMatesException(message: 'Please sign in.');
    }
    final login = await LoginSession.db.findFirstRow(
      session,
      where: (t) => t.tokenHash.equals(sha256Hex(authToken)),
    );
    if (login == null || login.expiresAt.isBefore(DateTime.now().toUtc())) {
      throw PoolMatesException(
        message: 'Your session has expired. Please sign in again.',
      );
    }
    final user = await UserProfile.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(login.userId),
    );
    if (user == null) {
      throw PoolMatesException(message: 'Account not found.');
    }
    return user;
  }
}
