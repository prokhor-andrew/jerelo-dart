import 'dart:async';

import 'package:jerelo/jerelo.dart';

// ---------------------------------------------------------------------------
// Domain models
// ---------------------------------------------------------------------------

final class UserProfile {
  final String id;
  final String name;
  final String email;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
  });

  UserProfile copyWith({String? name, String? email}) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
      );

  @override
  String toString() =>
      'UserProfile(id: $id, name: $name, email: $email)';
}

final class AuthToken {
  final String accessToken;
  final String refreshToken;

  const AuthToken({
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  String toString() =>
      'AuthToken(access: ${accessToken.substring(0, 8)}...)';
}

final class Session {
  final AuthToken token;
  final UserProfile profile;

  const Session({
    required this.token,
    required this.profile,
  });

  @override
  String toString() => 'Session(profile: $profile)';
}

// ---------------------------------------------------------------------------
// Mocked edge calls (simulating network latency with timers)
// ---------------------------------------------------------------------------

/// POST /auth/login – returns an auth token after 300ms.
Cont<void, String, AuthToken> loginRequest(
  String email,
  String password,
) {
  return Cont.fromRun((runtime, observer) {
    Timer(const Duration(milliseconds: 300), () {
      if (runtime.isCancelled()) return;

      if (email == 'user@test.com' &&
          password == 'secret') {
        print('  [API] POST /auth/login -> 200 OK');
        observer.onThen(
          const AuthToken(
            accessToken: 'eyJhbGciOiJIUzI1NiJ9.access',
            refreshToken: 'eyJhbGciOiJIUzI1NiJ9.refresh',
          ),
        );
      } else {
        print(
          '  [API] POST /auth/login -> 401 Unauthorized',
        );
        observer.onElse('Invalid credentials');
      }
    });
  });
}

/// GET /users/me – returns the user profile after 200ms.
Cont<void, String, UserProfile> getUserProfile(
  String accessToken,
) {
  return Cont.fromRun((runtime, observer) {
    Timer(const Duration(milliseconds: 200), () {
      if (runtime.isCancelled()) return;

      if (accessToken.isNotEmpty) {
        print('  [API] GET /users/me -> 200 OK');
        observer.onThen(
          const UserProfile(
            id: 'u_42',
            name: 'Alice',
            email: 'user@test.com',
          ),
        );
      } else {
        print('  [API] GET /users/me -> 403 Forbidden');
        observer.onElse('Missing token');
      }
    });
  });
}

/// PUT /users/me – updates the user profile after 250ms.
Cont<void, String, UserProfile> updateUserProfile(
  String accessToken,
  UserProfile updated,
) {
  return Cont.fromRun((runtime, observer) {
    Timer(const Duration(milliseconds: 250), () {
      if (runtime.isCancelled()) return;

      print('  [API] PUT /users/me -> 200 OK');
      observer.onThen(updated);
    });
  });
}

/// POST /auth/logout – invalidates the session after 150ms.
Cont<void, String, void> logoutRequest(String accessToken) {
  return Cont.fromRun((runtime, observer) {
    Timer(const Duration(milliseconds: 150), () {
      if (runtime.isCancelled()) return;

      print('  [API] POST /auth/logout -> 204 No Content');
      observer.onThen(null);
    });
  });
}

/// GET /users/me from a cache – immediate, but can fail.
Cont<void, String, UserProfile> getCachedProfile() {
  return Cont.fromRun((runtime, observer) {
    // Simulate cache miss
    print('  [CACHE] profile lookup -> miss');
    observer.onElse('Cache miss');
  });
}

// ---------------------------------------------------------------------------
// Composed flows using jerelo operators
// ---------------------------------------------------------------------------

/// Full login flow: authenticate, then fetch the user profile, producing a
/// [Session]. Uses `thenDo` for sequential dependent operations.
Cont<void, String, Session> loginFlow(
  String email,
  String password,
) {
  return loginRequest(email, password).thenDo((token) {
    return getUserProfile(token.accessToken).thenMap((
      profile,
    ) {
      return Session(token: token, profile: profile);
    });
  });
}

/// Attempt to load the profile from cache first; if it misses, fall back to
/// the network call. Demonstrates `elseDo` for recovery.
Cont<void, String, UserProfile> loadProfileWithFallback(
  String accessToken,
) {
  return getCachedProfile().elseDo((cacheError) {
    print(
      '  [FLOW] Cache failed ($cacheError), fetching from network...',
    );
    return getUserProfile(accessToken);
  });
}

/// Fetch profile and update it in one go. Uses `Cont.both` with a quit-fast
/// policy to run fetch + validation in parallel; both must succeed.
Cont<void, String, UserProfile> fetchAndUpdateProfile(
  String accessToken, {
  required String newName,
}) {
  final fetchProfile = getUserProfile(accessToken);
  final validateName = Cont.fromRun<void, String, String>((
    runtime,
    observer,
  ) {
    Timer(const Duration(milliseconds: 100), () {
      if (runtime.isCancelled()) return;

      if (newName.trim().isEmpty) {
        print('  [VALIDATION] name -> invalid');
        observer.onElse('Name cannot be empty');
      } else {
        print('  [VALIDATION] name -> ok');
        observer.onThen(newName.trim());
      }
    });
  });

  // Run fetch + validation in parallel; both must succeed.
  return Cont.both(
    fetchProfile,
    validateName,
    (profile, validatedName) =>
        profile.copyWith(name: validatedName),
    policy: OkPolicy.quitFast<String>(),
  ).thenDo((mergedProfile) {
    return updateUserProfile(accessToken, mergedProfile);
  });
}

/// Try two different login strategies: normal credentials vs. a stored refresh
/// token. Uses `Cont.either` to race them sequentially.
Cont<void, String, AuthToken> loginWithFallbackStrategy() {
  final normalLogin = loginRequest(
    'wrong@test.com',
    'nope',
  );
  final refreshLogin = Cont.fromRun<void, String, AuthToken>((
    runtime,
    observer,
  ) {
    Timer(const Duration(milliseconds: 200), () {
      if (runtime.isCancelled()) return;

      print('  [API] POST /auth/refresh -> 200 OK');
      observer.onThen(
        const AuthToken(
          accessToken: 'eyJhbGciOiJIUzI1NiJ9.refreshed',
          refreshToken: 'eyJhbGciOiJIUzI1NiJ9.refresh2',
        ),
      );
    });
  });

  // Try normal login first; if it fails, try refresh token.
  return Cont.either(
    normalLogin,
    refreshLogin,
    (e1, e2) => '$e1; $e2',
    policy: OkPolicy.sequence(),
  );
}

// ---------------------------------------------------------------------------
// Main – run every flow and print results
// ---------------------------------------------------------------------------

void main() {
  print('=== 1. Login flow (thenDo + thenMap) ===');
  loginFlow('user@test.com', 'secret')
      // thenTap: log the session without altering the value passed downstream.
      .thenTap((session) {
    print(
      '  [LOG] Authenticated as ${session.profile.name}',
    );
    return Cont.of(());
  }).run(
    null,
    onThen: (session) => print('  -> Success: $session\n'),
    onElse: (error) => print('  -> Failed: $error\n'),
  );

  print('=== 2. Profile with cache fallback (elseDo) ===');
  loadProfileWithFallback(
    'eyJhbGciOiJIUzI1NiJ9.access',
  ).run(
    null,
    onThen: (profile) => print('  -> Loaded: $profile\n'),
    onElse: (error) => print('  -> Failed: $error\n'),
  );

  print(
    '=== 3. Parallel fetch + validate, then update (Cont.both) ===',
  );
  fetchAndUpdateProfile(
    'eyJhbGciOiJIUzI1NiJ9.access',
    newName: 'Alice Wonderland',
  ).run(
    null,
    onThen: (profile) => print('  -> Updated: $profile\n'),
    onElse: (error) => print('  -> Failed: $error\n'),
  );

  print(
    '=== 4. Login with fallback strategy (Cont.either) ===',
  );
  loginWithFallbackStrategy().thenTap((token) {
    print('  [LOG] Got token via fallback: $token');
    return Cont.of(());
  }).run(
    null,
    onThen: (token) => print('  -> Token: $token\n'),
    onElse: (error) =>
        print('  -> All strategies failed: $error\n'),
  );

  print(
    '=== 5. Full session lifecycle (login -> update -> logout) ===',
  );
  loginFlow('user@test.com', 'secret').thenTap((session) {
    print('  [LOG] Session started');
    return Cont.of(());
  }).thenDo((session) {
    return fetchAndUpdateProfile(
      session.token.accessToken,
      newName: 'Alice Updated',
    ).thenMap((updatedProfile) {
      return Session(
        token: session.token,
        profile: updatedProfile,
      );
    });
  }).thenDo((session) {
    return logoutRequest(
      session.token.accessToken,
    ).thenMapTo(session);
  }).thenTap((session) {
    print(
      '  [LOG] Session ended for ${session.profile.name}',
    );
    return Cont.of(());
  }).run(
    null,
    onThen: (session) => print('  -> Final: $session\n'),
    onElse: (error) => print('  -> Failed: $error\n'),
  );
}
