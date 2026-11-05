# Changes from the first version

## Security
* **Real identity.** Email OTP sign-in + server-side session tokens. Before,
  every endpoint trusted a `userId` sent by the client, and login needed only
  an email address.
* **Women-only bypasses closed.** Unknown/missing profiles no longer default to
  "female" in search, and no longer skip the check when creating a women-only
  ride. Gender is set once and cannot be edited.
* **Chat is member-only** (ride chat read, write and live stream); sender comes
  from the session. Campus channels are limited to the user's own campus.
* **Share links:** 192-bit random tokens (`Random.secure`), expire 24 h after
  departure.
* **Seed endpoint is development-only** (it was public, and also re-seeded
  duplicate rides on every call).
* Date of birth is no longer collected (it was never stored; the demo now asks
  for an "18 or older" confirmation).

## Correctness
* **No overbooking:** each member gets a seat number with a unique
  (rideId, seatNo) index; `seatsTaken`/`status` are recomputed from real members.
* Rides that already departed are never matched or joinable.
* Place matching tolerates case, punctuation and aliases ("IGI Airport" = "Airport").
* Offer/request type can now be filtered.
* Fare: `farePerHead` is the price if you join now; new `projectedFarePerHead`
  is the price when full.
* The organiser can no longer leave their own ride (cancel instead).
* Matching uses 3 queries instead of one per ride/member; ties break by earliest departure.
* New accounts start with empty skills (they used to get fake default skills that inflated scores).
* Input limits: seats 2-8, fare range, 30-day horizon, message length, tag count, 3 active rides per user.

## Tests
* Matcher tests rewritten with a fixed clock; added ride-rules and place tests (30 total).

## Breaking API changes (client must update)
* `profile.registerOrLogin` removed, replaced by `auth.requestOtp` / `auth.verifyOtp`.
* All endpoints take `authToken`; `userId`, `campusId`, `senderId`, `requesterGender` parameters are gone.
* `Ride` gained `shareExpiresAt`; `RideMember` gained `seatNo`; `MatchedRide` gained `projectedFarePerHead`.
* New models: `EmailOtpCode`, `LoginSession`, `AuthResult`, `PoolMatesException`.
