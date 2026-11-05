import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../logic/auth_service.dart';
import '../logic/ride_rules.dart';

typedef OtpSender = Future<void> Function(
  Session session,
  String email,
  String code,
);

/// Plug your email provider in here once, e.g. in server.dart:
///   OtpMailer.sender = (session, email, code) async { ...SMTP / API... };
/// In development mode, with no sender set, the code is printed to the server log.
/// In production, with no sender set, sign-in is refused (fail closed).
class OtpMailer {
  static OtpSender? sender;
}

class AuthEndpoint extends Endpoint {
  static const Duration otpLifetime = Duration(minutes: 10);
  static const int maxAttempts = 5;
  static const int maxCodesPerHour = 5;

  /// Step 1: email a 6-digit code to a campus address.
  Future<bool> requestOtp(Session session, String email) async {
    final clean = AuthService.normalizeEmail(email);
    final domain = clean.split('@')[1];

    final campus = await Campus.db.findFirstRow(
      session,
      where: (t) => t.emailDomain.equals(domain),
    );
    if (campus == null) {
      throw PoolMatesException(
        message: 'Only verified campus emails (e.g. @bennett.edu.in) can join.',
      );
    }

    final now = DateTime.now().toUtc();

    final recent = await EmailOtpCode.db.count(
      session,
      where: (t) =>
          t.email.equals(clean) &
          t.createdAt.between(now.subtract(const Duration(hours: 1)), now),
    );
    if (recent >= maxCodesPerHour) {
      throw PoolMatesException(
        message: 'Too many codes requested. Please try again in an hour.',
      );
    }

    // housekeeping: forget codes older than a day
    await EmailOtpCode.db.deleteWhere(
      session,
      where: (t) => t.expiresAt.between(
        DateTime.utc(2000),
        now.subtract(const Duration(days: 1)),
      ),
    );

    final code = AuthService.randomOtp();
    await EmailOtpCode.db.insertRow(
      session,
      EmailOtpCode(
        email: clean,
        codeHash: AuthService.sha256Hex('$clean:$code'),
        attempts: 0,
        expiresAt: now.add(otpLifetime),
        createdAt: now,
      ),
    );

    final sender = OtpMailer.sender;
    if (sender != null) {
      await sender(session, clean, code);
    } else if (session.serverpod.runMode == 'development') {
      session.log('DEV ONLY - sign-in code for $clean is $code');
    } else {
      throw PoolMatesException(message: 'Email delivery is not configured.');
    }
    return true;
  }

  /// Step 2: exchange the code for a session token.
  /// First-time users must also pass name, branch, year and gender.
  /// Gender is stored once and cannot be changed later.
  Future<AuthResult> verifyOtp(
    Session session, {
    required String email,
    required String code,
    String? name,
    String? branch,
    int? year,
    String? gender,
  }) async {
    final clean = AuthService.normalizeEmail(email);
    final domain = clean.split('@')[1];
    final now = DateTime.now().toUtc();

    final latest = await EmailOtpCode.db.findFirstRow(
      session,
      where: (t) => t.email.equals(clean),
      orderBy: (t) => t.createdAt,
      orderDescending: true,
    );
    if (latest == null || latest.expiresAt.isBefore(now)) {
      throw PoolMatesException(
        message: 'Code expired or not found. Please request a new one.',
      );
    }
    if (latest.attempts >= maxAttempts) {
      throw PoolMatesException(
        message: 'Too many wrong attempts. Please request a new code.',
      );
    }

    final expected = AuthService.sha256Hex('$clean:${code.trim()}');
    if (!AuthService.constantTimeEquals(expected, latest.codeHash)) {
      latest.attempts += 1;
      await EmailOtpCode.db.updateRow(session, latest);
      throw PoolMatesException(message: 'Incorrect code.');
    }

    // one-time use
    await EmailOtpCode.db.deleteWhere(
      session,
      where: (t) => t.email.equals(clean),
    );

    var profile = await UserProfile.db.findFirstRow(
      session,
      where: (t) => t.email.equals(clean),
    );

    if (profile == null) {
      final campus = await Campus.db.findFirstRow(
        session,
        where: (t) => t.emailDomain.equals(domain),
      );
      if (campus == null) {
        throw PoolMatesException(message: 'Unknown campus.');
      }
      final cleanName = (name ?? '').trim();
      final cleanBranch = (branch ?? '').trim();
      final cleanGender = (gender ?? '').trim().toLowerCase();
      if (cleanName.isEmpty || cleanName.length > 80) {
        throw PoolMatesException(message: 'Please enter your name.');
      }
      if (cleanBranch.isEmpty || cleanBranch.length > 60) {
        throw PoolMatesException(message: 'Please enter your branch.');
      }
      if (year == null || year < 1 || year > 6) {
        throw PoolMatesException(message: 'Please enter your year (1-6).');
      }
      if (!RideRules.genders.contains(cleanGender)) {
        throw PoolMatesException(
          message: 'Please select female, male or other.',
        );
      }
      profile = await UserProfile.db.insertRow(
        session,
        UserProfile(
          userId: AuthService.newUserId(),
          campusId: campus.id!,
          name: cleanName,
          email: clean,
          branch: cleanBranch,
          year: year,
          gender: cleanGender,
          skills: [],
          interests: [],
          lookingFor: [],
          createdAt: now,
        ),
      );
    }

    final token = AuthService.randomToken();
    await LoginSession.db.insertRow(
      session,
      LoginSession(
        userId: profile.userId,
        tokenHash: AuthService.sha256Hex(token),
        expiresAt: now.add(AuthService.sessionLifetime),
        createdAt: now,
      ),
    );

    return AuthResult(authToken: token, profile: profile);
  }

  Future<bool> logout(Session session, String authToken) async {
    await LoginSession.db.deleteWhere(
      session,
      where: (t) => t.tokenHash.equals(AuthService.sha256Hex(authToken)),
    );
    return true;
  }
}
