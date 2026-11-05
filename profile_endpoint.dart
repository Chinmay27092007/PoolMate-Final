import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../logic/auth_service.dart';
import '../logic/ride_rules.dart';

class ProfileEndpoint extends Endpoint {
  Future<UserProfile> getMe(Session session, String authToken) =>
      AuthService.requireUser(session, authToken);

  /// Gender, email and campus are deliberately NOT editable here.
  Future<UserProfile> updateProfile(
    Session session,
    String authToken, {
    required String name,
    required String branch,
    required int year,
    String? bio,
    required List<String> skills,
    required List<String> interests,
    required List<String> lookingFor,
  }) async {
    final user = await AuthService.requireUser(session, authToken);

    final n = name.trim();
    final b = branch.trim();
    if (n.isEmpty || n.length > 80) {
      throw PoolMatesException(message: 'Please enter your name.');
    }
    if (b.isEmpty || b.length > 60) {
      throw PoolMatesException(message: 'Please enter your branch.');
    }
    if (year < 1 || year > 6) {
      throw PoolMatesException(message: 'Year must be between 1 and 6.');
    }
    final cleanBio = bio?.trim();
    if (cleanBio != null && cleanBio.length > 300) {
      throw PoolMatesException(
        message: 'Bio is too long (max 300 characters).',
      );
    }

    user.name = n;
    user.branch = b;
    user.year = year;
    user.bio = (cleanBio == null || cleanBio.isEmpty) ? null : cleanBio;
    user.skills = RideRules.cleanTags(skills);
    user.interests = RideRules.cleanTags(interests);
    user.lookingFor = RideRules.cleanTags(lookingFor);
    return UserProfile.db.updateRow(session, user);
  }
}
