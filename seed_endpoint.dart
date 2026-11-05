import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../logic/auth_service.dart';

/// Demo data for local development only. Refuses to run anywhere else, so a
/// deployed server cannot be reseeded (or polluted) by a stranger.
class SeedEndpoint extends Endpoint {
  Future<bool> seedDemoData(Session session) async {
    if (session.serverpod.runMode != 'development') {
      throw PoolMatesException(
        message: 'Seeding is only available in development mode.',
      );
    }

    var campus = await Campus.db.findFirstRow(
      session,
      where: (t) => t.emailDomain.equals('bennett.edu.in'),
    );
    campus ??= await Campus.db.insertRow(
      session,
      Campus(name: 'Bennett University', emailDomain: 'bennett.edu.in'),
    );
    final campusId = campus.id!;

    final existingChannels = await Channel.db.count(
      session,
      where: (t) => t.campusId.equals(campusId),
    );
    if (existingChannels == 0) {
      for (final ch in [
        Channel(
          campusId: campusId,
          name: '#general',
          description: 'General campus carpooling & chatter',
        ),
        Channel(
          campusId: campusId,
          name: '#airport-runs',
          description: 'Indira Gandhi International (DEL) rides',
        ),
        Channel(
          campusId: campusId,
          name: '#hackathons',
          description: 'Form teams on the way to hackathons!',
        ),
        Channel(
          campusId: campusId,
          name: '#clubs',
          description: 'Events, fests and club travel groups',
        ),
      ]) {
        await Channel.db.insertRow(session, ch);
      }
    }

    // Idempotent: only seed rides into an empty campus.
    final existingRides = await Ride.db.count(
      session,
      where: (t) => t.campusId.equals(campusId),
    );
    if (existingRides > 0) return true;

    final now = DateTime.now().toUtc();

    UserProfile u(
      String key,
      String name,
      String email,
      String branch,
      int year,
      String gender,
      String bio,
      List<String> skills,
      List<String> interests,
      List<String> lookingFor,
    ) => UserProfile(
      userId: 'demo_$key',
      campusId: campusId,
      name: name,
      email: email,
      branch: branch,
      year: year,
      gender: gender,
      bio: bio,
      skills: skills,
      interests: interests,
      lookingFor: lookingFor,
      createdAt: now,
    );

    final users = [
      u(
        'tanya',
        'Tanya Verma',
        'tanya.v@bennett.edu.in',
        'CSE',
        3,
        'female',
        'UI/UX Designer & Frontend enthusiast. Love hackathons!',
        ['designer', 'figma', 'frontend'],
        ['hackathons', 'design', 'travel'],
        ['developer', 'ml'],
      ),
      u(
        'kabir',
        'Kabir Joshi',
        'kabir.j@bennett.edu.in',
        'ECE',
        2,
        'male',
        'Video editor and filmmaker. Need a developer for my media startup.',
        ['editor', 'video editing', 'after effects'],
        ['cinematography', 'startups', 'gaming'],
        ['developer', 'marketing'],
      ),
      u(
        'ananya',
        'Ananya Roy',
        'ananya.r@bennett.edu.in',
        'Biotech',
        3,
        'female',
        'Heading home for the weekend. Guitar player.',
        ['content writer', 'guitarist'],
        ['music', 'reading', 'travel'],
        ['singer', 'editor'],
      ),
      u(
        'rohan',
        'Rohan Gupta',
        'rohan.g@bennett.edu.in',
        'CSE',
        4,
        'male',
        'ML researcher & backend builder. Looking for startup co-founders.',
        ['ml', 'python', 'backend'],
        ['ai', 'startups', 'chess'],
        ['designer', 'frontend'],
      ),
      u(
        'sneha',
        'Sneha Patel',
        'sneha.p@bennett.edu.in',
        'BBA',
        2,
        'female',
        'Growth marketing & social media lead. Looking for video editor!',
        ['marketing', 'growth', 'sales'],
        ['startups', 'podcasts', 'fests'],
        ['editor', 'video editing'],
      ),
    ];
    for (final user in users) {
      final exists = await UserProfile.db.count(
        session,
        where: (t) => t.userId.equals(user.userId),
      );
      if (exists == 0) await UserProfile.db.insertRow(session, user);
    }

    final byKey = {for (final x in users) x.userId: x};

    // creator, route, hours-from-now, seats, fare, womenOnly, extra members
    final plans = [
      (
        'demo_kabir',
        'Campus',
        'Airport',
        2.25,
        4,
        1400.0,
        false,
        ['demo_rohan'],
      ),
      ('demo_tanya', 'Campus', 'City Centre', 3.0, 3, 600.0, true, <String>[]),
      (
        'demo_rohan',
        'Railway Station',
        'Campus',
        5.0,
        4,
        800.0,
        false,
        <String>[],
      ),
      (
        'demo_ananya',
        'Campus',
        'Airport',
        2.4,
        3,
        1350.0,
        true,
        ['demo_sneha'],
      ),
    ];

    for (final p in plans) {
      final creator = byKey[p.$1]!;
      final dep = now.add(Duration(minutes: (p.$4 * 60).round()));
      final members = [creator, ...p.$8.map((id) => byKey[id]!)];

      final ride = await Ride.db.insertRow(
        session,
        Ride(
          campusId: campusId,
          creatorId: creator.userId,
          creatorName: creator.name,
          type: 'offer',
          origin: p.$2,
          destination: p.$3,
          departAt: dep,
          seatsTotal: p.$5,
          seatsTaken: members.length,
          totalFare: p.$6,
          womenOnly: p.$7,
          status: 'open',
          shareToken: 'pm_${AuthService.randomToken(bytes: 24)}',
          shareExpiresAt: dep.add(const Duration(hours: 24)),
          createdAt: now,
        ),
      );
      for (var i = 0; i < members.length; i++) {
        await RideMember.db.insertRow(
          session,
          RideMember(
            rideId: ride.id!,
            userId: members[i].userId,
            userName: members[i].name,
            userGender: members[i].gender,
            role: i == 0 ? 'creator' : 'member',
            seatNo: i,
            joinedAt: now,
          ),
        );
      }
    }
    return true;
  }
}
