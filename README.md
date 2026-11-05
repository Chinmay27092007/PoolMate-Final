# PoolMates

Campus cab-pooling with skill-based matching, women-only rides and group chat.
Built for the Campus Life hackathon track (Flutter + Serverpod).

```
PoolMates/
  poolmates_server/   Serverpod backend (models, endpoints, logic, tests)
  poolmates_flutter/  Theme + route painter for the Flutter app
  web_demo/           index.html UI prototype (no backend, simulated data)
  CHANGELOG.md        What changed vs. the first version, and why
```

## Important: what is and isn't wired up

* `web_demo/index.html` is a **UI prototype**. It keeps everything in browser
  memory and does not talk to the server. Run it with `web_demo/START_POOLMATES.bat`
  or by opening the file.
* `poolmates_server/` is the real backend. The Flutter app should call it
  through the generated Serverpod client. The Flutter app itself still needs to
  be built; this repo ships only its theme and painter.

## Backend setup

The files in `lib/src` are meant to drop into a Serverpod project
(`serverpod create poolmates`, then copy `lib/src/protocol`, `lib/src/logic`
and `lib/src/endpoints` over the generated ones).

1. `dart pub add crypto`  (Serverpod already depends on it; this makes it explicit)
2. `serverpod generate`
3. `serverpod create-migration` then start the server with `--apply-migrations`
4. Development only: call `seed.seedDemoData()` for demo users, rides and channels.
5. Production: set an email sender once at start-up, otherwise sign-in is refused:

```dart
OtpMailer.sender = (session, email, code) async {
  // send `code` to `email` with your SMTP / API provider
};
```

Tests: `dart test` (matcher, ride rules, place normaliser).

## How sign-in works now

1. `auth.requestOtp(email)`: campus-domain emails only; 5 codes/hour; code valid 10 min.
2. `auth.verifyOtp(email, code, name?, branch?, year?, gender?)`: returns an
   `authToken` (and the profile). New users must also send name, branch, year, gender.
3. Every other endpoint takes that `authToken` as its second argument. The server
   works out who you are from it. No endpoint accepts a user id from the client.

## Known limitations

* **Gender is self-declared** (chosen once at sign-up, then locked). Women-only
  rides are only as trustworthy as that declaration. For stronger guarantees,
  add manual verification (e.g. ID check by a campus admin) before allowing
  women-only rides.
* The share link and OTP endpoints have no IP-level rate limiting; put the
  server behind a proxy/WAF in production.
* Not yet built: SOS / live location, ratings, report/block, push notifications,
  UPI settle-up, recurring rides.
